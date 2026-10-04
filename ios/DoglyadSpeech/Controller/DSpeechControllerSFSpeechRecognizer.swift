import Combine
import Foundation
import Speech

/// Speech recognition on the classic `SFSpeechRecognizer` (available on every
/// supported iOS version). It starts only when on-device recognition is supported
/// and available; a fallback never sends patient audio to Apple's servers.
///
/// A single `SFSpeechRecognizer` task has a duration limit (about a minute), after
/// which the service finalizes it itself. So that a long examination dictation is not
/// cut short, the audio engine is kept running the whole time while the recognition
/// task is recreated on every final result or error, accumulating the finished chunks
/// into one text. The audio tail at the seam is carried over by ``DSpeechAudioRelay``.
@MainActor
public final class DSpeechControllerSFSpeechRecognizer: DSpeechControllerProtocol {
    /// Tap buffer size. At 48 kHz that is roughly 21 ms of audio.
    private static let tapBufferSize: AVAudioFrameCount = 1024
    /// How long we wait for the final result after the microphone stops.
    private static let finalizationTimeout: Duration = .seconds(3)

    private let speechRecognizer: SFSpeechRecognizer?
    private let locale: Locale
    /// Hints for the recognizer: examination-specific vocabulary for the current locale.
    private let contextualStrings: [String]
    /// The same vocabulary, but as post-processing: hints bias recognition, while the
    /// corrector repairs what still came out wrong.
    private let corrector: DSpeechLexiconCorrector
    /// Recreated for every session: voice processing can only be toggled on a stopped
    /// engine, and its state outlives `stop()` — restarting with a different audio
    /// route then leads to an invalid format.
    private var audioEngine = AVAudioEngine()
    private let relay = DSpeechAudioRelay()
    private lazy var meter = DSpeechAudioMeter { [weak self] level in
        DispatchQueue.main.async {
            self?.audioMeter = level
        }
    }

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var session = DictationSessionGate()
    private var finalizationTimeoutTask: Task<Void, Never>?
    private var finalizationCompletion: DictationCompletion = .finished
    private var hadUnfinalizedSegment = false
    private var hasTap = false

    /// Marks an active session: tells a restart on the duration limit (keep going)
    /// apart from a stop by the user (do not restart).
    private var isRunning = false
    /// Finalized segments of previous tasks, glued into a single text.
    private var finalizedText = ""
    /// The last "draft" transcript of the current task — in case the task is cut short
    /// by an error or the limit without a final result, so the tail is not lost.
    private var lastPartial = ""
    /// Waiting for the final result after `stop()`.
    private var finalizationContinuation: CheckedContinuation<String, Never>?

    @Published public var status: DRecordingStatus = .stopped
    @Published public var text: String?
    @Published public var audioMeter: Float = 0.0
    @Published public private(set) var lastTranscript: DictationTranscript?

    public init(
        locale: Locale,
        contextualStrings: [String]
    ) {
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        self.locale = locale
        self.contextualStrings = contextualStrings
        corrector = DSpeechLexiconCorrector(terms: contextualStrings)
    }

    public func start() {
        switch status {
        case .stopped:
            break
        case .preparing, .recording, .transcribing:
            return
        }
        guard !audioEngine.isRunning else { return }
        // Without an available recognizer, recording is pointless: the engine would
        // record while no text ever appeared.
        guard let recognizer = speechRecognizer,
              recognizer.isAvailable,
              recognizer.supportsOnDeviceRecognition
        else {
            lastTranscript = DictationTranscript(
                rawText: "",
                correctedText: "",
                locale: locale,
                engine: .sfSpeechRecognizer,
                completion: .failed
            )
            return
        }
        guard let sessionID = session.start() else { return }

        status = .preparing
        text = nil
        lastTranscript = nil
        finalizedText = ""
        lastPartial = ""
        audioMeter = 0.0
        finalizationCompletion = .finished
        hadUnfinalizedSegment = false

        do {
            let route = try DSpeechAudioSession.activate()
            audioEngine = AVAudioEngine()

            // The tap and the engine live for the whole session: buffers always go to the
            // current task, and recreating that task neither breaks the audio stream nor
            // loses words at the seam.
            let (inputNode, recordingFormat) = try prepareInputNode(route: route)
            relay.prepare(format: recordingFormat, bufferFrames: Self.tapBufferSize)

            let relay = relay
            let meter = meter
            inputNode.installTap(onBus: 0, bufferSize: Self.tapBufferSize, format: recordingFormat) { buffer, _ in
                relay.append(buffer)
                meter.process(buffer)
            }
            hasTap = true

            isRunning = true
            startTask(sessionID: sessionID)

            audioEngine.prepare()
            try audioEngine.start()

            status = .recording
        } catch {
            session.cancel()
            lastTranscript = DictationTranscript(
                rawText: text ?? "",
                correctedText: text ?? "",
                locale: locale,
                engine: .sfSpeechRecognizer,
                completion: .failed
            )
            teardown()
        }
    }

    /// Prepares the input node and returns a format that is safe to install a tap on.
    ///
    /// Voice processing rebuilds the input audio unit, and right after enabling it the
    /// node may report a format with a zero sample rate. `installTap` on such a format
    /// trips an assert, so the format is validated and, on failure, processing is
    /// rolled back: dictation without noise suppression beats a crash.
    private func prepareInputNode(
        route: DSpeechAudioRoute
    ) throws -> (AVAudioInputNode, AVAudioFormat) {
        let inputNode = audioEngine.inputNode

        // Stationary noise suppression (the scanner's hum), echo cancellation,
        // automatic gain. Needed when the phone lies off to the side, and not needed
        // on a headset where the microphone is at the mouth anyway.
        let useVoiceProcessing: Bool
        switch route {
        case .builtIn:
            useVoiceProcessing = true
        case .headset:
            useVoiceProcessing = false
        }
        try? inputNode.setVoiceProcessingEnabled(useVoiceProcessing)

        var recordingFormat = inputNode.outputFormat(forBus: 0)
        if !recordingFormat.isValidForCapture, inputNode.isVoiceProcessingEnabled {
            try? inputNode.setVoiceProcessingEnabled(false)
            recordingFormat = inputNode.outputFormat(forBus: 0)
        }
        guard recordingFormat.isValidForCapture else {
            throw DSpeechError.unavailable
        }

        return (inputNode, recordingFormat)
    }

    @discardableResult
    public func stop() async -> DictationTranscript? {
        await stop(completion: .finished)
    }

    private func stop(completion requestedCompletion: DictationCompletion) async -> DictationTranscript? {
        guard isRunning, let sessionID = session.activeID,
              session.beginFinalization(for: sessionID) else { return lastTranscript }

        isRunning = false
        audioEngine.stop()
        if hasTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasTap = false
        }
        relay.detach()
        meter.reset()
        status = .stopped

        let result = await finalize()
        guard session.finish(for: sessionID) else { return nil }

        teardown()
        let correctedText = corrector.correct(result)
        text = correctedText.isEmpty ? nil : correctedText

        let completion: DictationCompletion
        switch requestedCompletion {
        case .finished:
            switch finalizationCompletion {
            case .finished:
                completion = hadUnfinalizedSegment ? .interrupted : .finished
            case .timedOut, .interrupted, .cancelled, .failed:
                completion = finalizationCompletion
            }
        case .timedOut, .interrupted, .cancelled, .failed:
            completion = requestedCompletion
        }
        let transcript = DictationTranscript(
            rawText: result,
            correctedText: correctedText,
            locale: locale,
            engine: .sfSpeechRecognizer,
            completion: completion
        )
        lastTranscript = transcript
        return transcript
    }

    @discardableResult
    public func cancel() -> DictationTranscript? {
        guard session.cancel() != nil else { return lastTranscript }

        finalizationCompletion = .cancelled
        finishFinalization(with: nil)
        let rawText = text ?? combine(finalizedText, lastPartial)
        let correctedText = corrector.correct(rawText)
        teardown()
        text = correctedText.isEmpty ? nil : correctedText

        let transcript = DictationTranscript(
            rawText: rawText,
            correctedText: correctedText,
            locale: locale,
            engine: .sfSpeechRecognizer,
            completion: .cancelled
        )
        lastTranscript = transcript
        return transcript
    }

    /// Asks the service to finish the remaining audio and waits for the final result.
    /// Without this the tail of the dictation would be lost: `cancel()` throws away
    /// unfinished results, and parsing starts right after the stop.
    private func finalize() async -> String {
        guard let request = recognitionRequest, recognitionTask != nil else {
            finalizationCompletion = .interrupted
            return combine(finalizedText, lastPartial)
        }

        request.endAudio()

        let segment = await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
            finalizationContinuation = continuation
            finalizationTimeoutTask = Task { [weak self] in
                try? await Task.sleep(for: Self.finalizationTimeout)
                guard !Task.isCancelled else { return }
                self?.finalizationCompletion = .timedOut
                self?.finishFinalization(with: nil)
            }
        }
        finalizationTimeoutTask?.cancel()
        finalizationTimeoutTask = nil

        return combine(finalizedText, segment)
    }

    /// Ends the wait for the final. `segment == nil` means a timeout or an error, in
    /// which case the last draft of the current task is used.
    private func finishFinalization(
        with segment: String?
    ) {
        guard let continuation = finalizationContinuation else { return }

        finalizationContinuation = nil
        continuation.resume(returning: segment ?? lastPartial)
    }

    private func teardown() {
        isRunning = false
        audioEngine.stop()
        if hasTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasTap = false
        }
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        finalizationTimeoutTask?.cancel()
        finalizationTimeoutTask = nil
        relay.reset()
        audioMeter = 0.0
        status = .stopped
        DSpeechAudioSession.deactivate()
    }

    /// Creates a new recognition task on top of the running audio engine.
    private func startTask(sessionID: UUID) {
        guard session.acceptsResult(for: sessionID) else { return }
        guard let recognizer = speechRecognizer,
              recognizer.isAvailable,
              recognizer.supportsOnDeviceRecognition
        else {
            Task { [weak self] in
                _ = await self?.stop(completion: .failed)
            }
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        request.addsPunctuation = true
        request.taskHint = .dictation
        request.contextualStrings = contextualStrings
        recognitionRequest = request
        lastPartial = ""

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                self?.handleResult(result, error: error, request: request, sessionID: sessionID)
            }
        }

        // Attached last: `attach` immediately pours the previous task's tail into the
        // request, and that must happen with the callback already in place.
        relay.attach(request)
    }

    private func handleResult(
        _ result: SFSpeechRecognitionResult?,
        error: (any Error)?,
        request: SFSpeechAudioBufferRecognitionRequest,
        sessionID: UUID
    ) {
        // Ignore delayed callbacks from an already recreated task.
        guard session.acceptsResult(for: sessionID), request === recognitionRequest else { return }

        if let result {
            let segment = result.bestTranscription.formattedString
            lastPartial = segment
            if isRunning {
                text = combine(finalizedText, segment)
            }
            guard result.isFinal else { return }

            guard isRunning else {
                finishFinalization(with: segment)
                return
            }
            // Duration limit or a pause: record the segment and carry on.
            commitCurrentSegment(segment)
            startTask(sessionID: sessionID)
            return
        }

        guard error != nil else { return }

        guard isRunning else {
            finalizationCompletion = .interrupted
            finishFinalization(with: nil)
            return
        }
        // The task ended without a final — keep the last draft and continue.
        hadUnfinalizedSegment = true
        commitCurrentSegment(lastPartial)
        startTask(sessionID: sessionID)
    }

    /// Appends a finished segment to the accumulated text and clears the draft.
    private func commitCurrentSegment(
        _ segment: String
    ) {
        relay.detach()
        recognitionRequest?.endAudio()
        recognitionTask = nil
        recognitionRequest = nil

        finalizedText = combine(finalizedText, segment)
        lastPartial = ""
        text = finalizedText
    }

    /// Joins two chunks with a space, handling empty strings gracefully.
    private func combine(
        _ base: String,
        _ addition: String
    ) -> String {
        let trimmed = addition.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return base }
        guard !base.isEmpty else { return trimmed }

        return base + " " + trimmed
    }
}
