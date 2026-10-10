import AVFoundation
import Combine
import Foundation
import Speech

/// Speech recognition on the new `SpeechAnalyzer` stack (iOS 26+).
///
/// It works on-device, without the one-minute limit and with streaming results,
/// which suits long examination dictations better. The language model is downloaded
/// through ``AssetInventory`` when needed — during that time the session stays in
/// the `preparing` state and the microphone is not recording yet.
///
/// `DictationTranscriber` was chosen as the recognition module rather than
/// `SpeechTranscriber`: only it reads `AnalysisContext.contextualStrings`
/// (`SpeechTranscriber` silently ignores them) and only it has the `.farField` hint —
/// and the physician's phone often lies on the scanner rather than near their mouth.
@available(iOS 26.0, *)
@MainActor
public final class DSpeechControllerAnalyzer: DSpeechControllerProtocol {
    /// Tap buffer size. At 48 kHz that is roughly 21 ms of audio.
    private static let tapBufferSize: AVAudioFrameCount = 1024
    /// How long we wait for the analyzer to finish the audio tail after stopping.
    private static let finalizationTimeout: Duration = .seconds(
        3,
    )

    /// Whether the transcriber supports the given locale. Asynchronous because the
    /// locale list is delivered via `await`. The factory asks this before choosing an
    /// implementation and falls back to `SFSpeechRecognizer` on an uncovered locale.
    public static func isSupported(
        locale: Locale,
    ) async -> Bool {
        await DictationTranscriber.supportedLocale(
            equivalentTo: locale,
        ) != nil
    }

    private let locale: Locale
    /// Examination vocabulary: specific terms the recognizer otherwise consistently
    /// mishears.
    private let contextualStrings: [String]
    /// The same vocabulary as post-processing: hints bias recognition, while the
    /// corrector repairs what still came out wrong.
    private let corrector: DSpeechLexiconCorrector
    /// Recreated for every session: voice processing can only be toggled on a stopped
    /// engine, and its state outlives `stop()` — restarting with a different audio
    /// route then leads to an invalid format.
    private var audioEngine = AVAudioEngine()
    private let converter = DSpeechBufferConverter()
    private lazy var meter = DSpeechAudioMeter { [weak self] level in
        DispatchQueue.main.async {
            self?.audioMeter = level
        }
    }

    private var analyzer: SpeechAnalyzer?
    private var transcriber: DictationTranscriber?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var recognizerTask: Task<Void, Never>?
    private var startTask: Task<Void, Never>?
    private var finalizationTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var finalizationContinuation: CheckedContinuation<Void, Never>?
    private var session = DSpeechSessionGate()
    private var hasTap = false
    private var wasTimedOut = false
    private var recognizerFailed = false

    /// Accumulated finalized text: the "draft" chunk of the current phrase is appended
    /// to it so that speech is visible on screen in real time.
    private var finalizedText = AttributedString()

    @Published public var status: DSpeechRecordingStatus = .stopped
    @Published public var text: String?
    @Published public var audioMeter: Float = 0.0
    @Published public private(set) var lastTranscript: DSpeechTranscript?

    public init(
        locale: Locale,
        contextualStrings: [String],
        lexiconLocalization: DSpeechLexiconLocalization,
    ) {
        self.locale = locale
        self.contextualStrings = contextualStrings
        corrector = DSpeechLexiconCorrector(
            terms: contextualStrings,
            localization: lexiconLocalization,
        )
    }

    public func start() {
        switch status {
        case .stopped:
            break
        case .preparing, .recording, .transcribing:
            return
        }
        guard let sessionID = session.start() else { return }

        status = .preparing
        text = nil
        lastTranscript = nil
        audioMeter = 0.0
        finalizedText = AttributedString()
        wasTimedOut = false
        recognizerFailed = false

        startTask = Task { [weak self] in
            do {
                try await self?.beginTranscription(
                    sessionID: sessionID,
                )
            } catch {
                guard let self, session.acceptsResult(
                    for: sessionID,
                ) else { return }
                _ = await stop(
                    completion: .failed,
                )
            }
        }
    }

    @discardableResult
    public func stop() async -> DSpeechTranscript? {
        await stop(
            completion: .finished,
        )
    }

    private func stop(
        completion requestedCompletion: DSpeechCompletion,
    ) async -> DSpeechTranscript? {
        guard let sessionID = session.activeID,
              session.beginFinalization(
                  for: sessionID,
              ) else { return lastTranscript }

        audioEngine.stop()
        if hasTap {
            audioEngine.inputNode.removeTap(
                onBus: 0,
            )
            hasTap = false
        }
        meter.reset()
        status = .stopped

        startTask?.cancel()
        startTask = nil

        inputBuilder?.finish()
        inputBuilder = nil

        // Let the analyzer finish the audio tail and wait for the final result:
        // dictation parsing starts right after `stop()`, and the last phrase arrives
        // in the result stream only after finalization.
        let analyzer = analyzer
        let recognizerTask = recognizerTask
        self.analyzer = nil
        transcriber = nil
        self.recognizerTask = nil

        // Resume on either completion or timeout. Waiting for a cancelled Apple task
        // here could otherwise keep the sheet blocked past the timeout.
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            finalizationContinuation = continuation
            let finalization = Task { [weak self] in
                do {
                    try await analyzer?.finalizeAndFinishThroughEndOfInput()
                } catch {
                    guard let self, session.acceptsResult(
                        for: sessionID,
                    ) else { return }
                    recognizerFailed = true
                }
                await recognizerTask?.value
                self?.finishFinalizationWait(
                    for: sessionID,
                )
            }
            finalizationTask = finalization
            timeoutTask = Task { [weak self] in
                try? await Task.sleep(
                    for: Self.finalizationTimeout,
                )
                guard !Task.isCancelled else { return }
                guard let self, session.acceptsResult(
                    for: sessionID,
                ),
                    finalizationContinuation != nil else { return }
                wasTimedOut = true
                finalization.cancel()
                recognizerTask?.cancel()
                Task { await analyzer?.cancelAndFinishNow() }
                finishFinalizationWait(
                    for: sessionID,
                )
            }
        }
        if session.acceptsResult(
            for: sessionID,
        ) {
            timeoutTask?.cancel()
            timeoutTask = nil
            finalizationTask = nil
        }

        guard session.finish(
            for: sessionID,
        ) else { return nil }

        let completion: DSpeechCompletion = switch requestedCompletion {
        case .finished:
            wasTimedOut ? .timedOut : (recognizerFailed ? .interrupted : .finished)
        case .timedOut, .interrupted, .cancelled, .failed:
            requestedCompletion
        }

        audioMeter = 0.0
        DSpeechAudioSession.deactivate()

        let finalized = String(
            finalizedText.characters,
        )
        let rawText: String = switch completion {
        case .finished:
            finalized
        case .timedOut, .interrupted, .cancelled, .failed:
            text ?? finalized
        }
        let correctedText = corrector.correct(
            rawText,
        )
        text = correctedText.isEmpty ? nil : correctedText
        let confidenceSpans: [DSpeechConfidenceSpan] = switch completion {
        case .finished:
            DSpeechConfidenceSpan.from(
                finalizedText,
            )
        case .timedOut, .interrupted, .cancelled, .failed:
            []
        }
        let transcript = DSpeechTranscript(
            rawText: rawText,
            correctedText: correctedText,
            locale: locale,
            engine: .speechAnalyzer,
            completion: completion,
            confidenceSpans: confidenceSpans,
        )
        lastTranscript = transcript
        return transcript
    }

    @discardableResult
    public func cancel() -> DSpeechTranscript? {
        guard session.cancel() != nil else { return lastTranscript }

        startTask?.cancel()
        startTask = nil
        finalizationTask?.cancel()
        timeoutTask?.cancel()
        finishFinalizationWait()
        recognizerTask?.cancel()
        recognizerTask = nil
        inputBuilder?.finish()
        inputBuilder = nil
        if let analyzer {
            Task { await analyzer.cancelAndFinishNow() }
        }
        analyzer = nil
        transcriber = nil

        audioEngine.stop()
        if hasTap {
            audioEngine.inputNode.removeTap(
                onBus: 0,
            )
            hasTap = false
        }
        meter.reset()
        audioMeter = 0.0
        status = .stopped
        DSpeechAudioSession.deactivate()

        let rawText = text ?? String(
            finalizedText.characters,
        )
        let correctedText = corrector.correct(
            rawText,
        )
        text = correctedText.isEmpty ? nil : correctedText
        let transcript = DSpeechTranscript(
            rawText: rawText,
            correctedText: correctedText,
            locale: locale,
            engine: .speechAnalyzer,
            completion: .cancelled,
        )
        lastTranscript = transcript
        return transcript
    }

    private func finishFinalizationWait(
        for sessionID: UUID,
    ) {
        guard session.acceptsResult(
            for: sessionID,
        ) else { return }
        finishFinalizationWait()
    }

    private func finishFinalizationWait() {
        let continuation = finalizationContinuation
        finalizationContinuation = nil
        continuation?.resume()
    }

    private func beginTranscription(
        sessionID: UUID,
    ) async throws {
        let route = try DSpeechAudioSession.activate()

        // The device locale may differ by region from a supported one (or not be
        // supported at all) — pick the one the transcriber actually knows.
        // In the normal flow the factory has already checked support, so nil here
        // is a safety net.
        guard let resolvedLocale = await DictationTranscriber.supportedLocale(
            equivalentTo: locale,
        ) else {
            throw DSpeechError.unavailable
        }
        try Task.checkCancellation()

        // `.farField` is a hint that the speaker is not right up against the mic. On a
        // headset that would be a lie, so it is set only for the built-in microphone.
        var isFarField = false
        switch route {
        case .builtIn:
            isFarField = true
        case .headset:
            break
        }

        let transcriber = DSpeechAnalyzerConfiguration.makeTranscriber(
            locale: resolvedLocale,
            isFarField: isFarField,
            includeConfidence: true,
        )
        self.transcriber = transcriber

        let analyzer = SpeechAnalyzer(
            modules: [transcriber],
        )
        self.analyzer = analyzer

        // The whole point of the exercise: examination vocabulary reaches the recognizer.
        try await DSpeechAnalyzerConfiguration.setContext(
            on: analyzer,
            contextualStrings: contextualStrings,
        )
        try Task.checkCancellation()

        try await DSpeechAnalyzerConfiguration.installModelIfNeeded(
            transcriber: transcriber,
        )
        try Task.checkCancellation()

        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: [transcriber],
        ) else {
            throw DSpeechError.unavailable
        }
        try Task.checkCancellation()

        let (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()
        self.inputBuilder = inputBuilder

        // Streaming results: final phrases accumulate, the draft one is appended on top.
        recognizerTask = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    guard let self, session.acceptsResult(
                        for: sessionID,
                    ) else { return }
                    if result.isFinal {
                        finalizedText += result.text
                        text = String(
                            finalizedText.characters,
                        )
                    } else {
                        text = String(
                            (finalizedText + result.text).characters,
                        )
                    }
                }
            } catch {
                guard let self, session.acceptsResult(
                    for: sessionID,
                ) else { return }
                recognizerFailed = true
            }
            guard let self, session.acceptsResult(
                for: sessionID,
            ),
                !self.session.isFinalizing else { return }
            Task { [weak self] in
                _ = await self?.stop(
                    completion: .interrupted,
                )
            }
        }

        try await analyzer.start(
            inputSequence: inputSequence,
        )

        // The user could have closed the sheet while the model was loading.
        try Task.checkCancellation()

        audioEngine = AVAudioEngine()
        let (inputNode, recordingFormat) = try prepareInputNode(
            route: route,
        )
        let converter = converter
        let meter = meter
        inputNode.installTap(
            onBus: 0,
            bufferSize: Self.tapBufferSize,
            format: recordingFormat,
        ) { buffer, _ in
            meter.process(
                buffer,
            )

            guard let converted = try? converter.convert(
                buffer,
                to: analyzerFormat,
            ) else { return }
            inputBuilder.yield(
                AnalyzerInput(
                    buffer: converted,
                ),
            )
        }
        hasTap = true

        audioEngine.prepare()
        try audioEngine.start()

        status = .recording
    }

    /// Prepares the input node and returns a format that is safe to install a tap on.
    ///
    /// Voice processing rebuilds the input audio unit, and right after enabling it the
    /// node may report a format with a zero sample rate. `installTap` on such a format
    /// trips an assert, so the format is validated and, on failure, processing is
    /// rolled back: dictation without noise suppression beats a crash.
    private func prepareInputNode(
        route: DSpeechAudioRoute,
    ) throws -> (AVAudioInputNode, AVAudioFormat) {
        let inputNode = audioEngine.inputNode

        // Stationary noise suppression (the scanner's hum), echo cancellation,
        // automatic gain. Needed when the phone lies off to the side, and not needed
        // on a headset where the microphone is at the mouth anyway.
        let useVoiceProcessing = switch route {
        case .builtIn:
            true
        case .headset:
            false
        }
        try? inputNode.setVoiceProcessingEnabled(
            useVoiceProcessing,
        )

        var recordingFormat = inputNode.outputFormat(
            forBus: 0,
        )
        if !recordingFormat.isValidForCapture, inputNode.isVoiceProcessingEnabled {
            try? inputNode.setVoiceProcessingEnabled(
                false,
            )
            recordingFormat = inputNode.outputFormat(
                forBus: 0,
            )
        }
        guard recordingFormat.isValidForCapture else {
            throw DSpeechError.unavailable
        }

        return (inputNode, recordingFormat)
    }
}
