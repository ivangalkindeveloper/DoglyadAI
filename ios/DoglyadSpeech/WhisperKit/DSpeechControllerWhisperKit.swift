import AVFoundation
import Combine
import Foundation
import WhisperKit

/// Publishes a live preview and verifies the complete recording after stopping.
@MainActor
public final class DSpeechControllerWhisperKit: DSpeechControllerProtocol {
    private let locale: Locale
    private let corrector: DSpeechLexiconCorrector
    private let modelStore = DSpeechWhisperKitModel.shared
    private var modelCancellable: AnyCancellable?
    private var audioProcessor: DSpeechWhisperKitAudioProcessor?
    private var streamTranscriber: AudioStreamTranscriber?
    private var streamTask: Task<Void, Never>?
    private var meterTimer: Timer?
    private var transcriptionTask: Task<DSpeechWhisperKitTranscription, Error>?
    private var lastPartialText = ""
    private var session = DSpeechSessionGate()

    @Published public private(set) var recordingStatus: DSpeechRecordingStatus = .stopped
    @Published public private(set) var text: String?
    @Published public private(set) var audioMeter: Float = 0
    @Published public private(set) var lastTranscript: DSpeechTranscript?
    @Published public private(set) var modelPreparationStatus: DSpeechModelPreparationStatus = .checking

    public init(
        locale: Locale,
        contextualStrings: [String],
        lexiconLocalization: DSpeechLexiconLocalization,
    ) {
        self.locale = locale
        corrector = DSpeechLexiconCorrector(
            terms: contextualStrings,
            localization: lexiconLocalization,
        )
        modelCancellable = modelStore.$state.sink { [weak self] state in
            self?.modelPreparationStatus = state
        }
    }

    public func prepareModel() {
        modelStore.prepare()
    }

    public func start() {
        switch recordingStatus {
        case .stopped: break
        case .preparing, .recording, .transcribing: return
        }
        guard case .ready = modelPreparationStatus else { return }
        guard let sessionID = session.start() else { return }

        recordingStatus = .preparing
        text = nil
        lastTranscript = nil
        lastPartialText = ""
        audioMeter = 0
        // A cancelled decoder must drain before the shared model is used again.
        let previousStream = streamTask
        let previousTranscription = transcriptionTask
        streamTask = Task { [weak self] in
            await previousStream?.value
            _ = await previousTranscription?.result
            guard !Task.isCancelled else { return }
            do {
                guard let store = self?.modelStore else { return }
                try await store.performInference { [weak self] model in
                    guard let stream = try self?.makeStream(
                        model: model,
                        for: sessionID,
                    ) else { return }
                    try await stream.startStreamTranscription()
                }
                guard let self, session.acceptsResult(
                    for: sessionID,
                ), !session.isFinalizing else { return }
                // The stream has ended, so stop() must not await its own task.
                streamTask = nil
                _ = await stop(
                    completion: .interrupted,
                )
            } catch {
                self?.failSession(
                    sessionID,
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

    @discardableResult
    public func cancel() -> DSpeechTranscript? {
        guard session.cancel() != nil else { return lastTranscript }

        streamTask?.cancel()
        transcriptionTask?.cancel()
        audioProcessor?.stopRecording()
        audioProcessor = nil
        let stream = streamTranscriber
        streamTranscriber = nil
        Task { await stream?.stopStreamTranscription() }
        stopMeter()
        DSpeechAudioSession.deactivate()
        text = nil
        lastPartialText = ""
        recordingStatus = .stopped
        return nil
    }

    private func makeStream(
        model: WhisperKit,
        for sessionID: UUID,
    ) throws -> AudioStreamTranscriber? {
        try Task.checkCancellation()
        guard session.acceptsResult(
            for: sessionID,
        ), !session.isFinalizing else { return nil }
        guard let tokenizer = model.tokenizer else { throw DSpeechError.unavailable }
        let processor = DSpeechWhisperKitAudioProcessor()
        let stream = AudioStreamTranscriber(
            audioEncoder: model.audioEncoder,
            featureExtractor: model.featureExtractor,
            segmentSeeker: model.segmentSeeker,
            textDecoder: model.textDecoder,
            tokenizer: tokenizer,
            audioProcessor: processor,
            decodingOptions: DecodingOptions(
                language: locale.language.languageCode?.identifier ?? locale.identifier,
            ),
            stateChangeCallback: { [weak self] oldState, state in
                guard oldState.confirmedSegments != state.confirmedSegments
                    || oldState.unconfirmedSegments != state.unconfirmedSegments
                    || (oldState.bufferEnergy.isEmpty && !state.bufferEnergy.isEmpty) else { return }
                let preview = DSpeechWhisperKitTranscription.previewText(
                    confirmedSegments: state.confirmedSegments,
                    unconfirmedSegments: state.unconfirmedSegments,
                )
                Task { @MainActor [weak self] in
                    self?.receiveStreamText(
                        preview,
                        for: sessionID,
                    )
                }
            },
        )
        audioProcessor = processor
        streamTranscriber = stream
        return stream
    }

    private func receiveStreamText(
        _ preview: String?,
        for sessionID: UUID,
    ) {
        guard session.acceptsResult(
            for: sessionID,
        ), !session.isFinalizing else { return }
        if meterTimer == nil, audioProcessor?.isRecording == true {
            recordingStatus = .recording
            startMeter(
                for: sessionID,
            )
        }
        // Only ASR segments are displayed. The SDK's currentText also contains
        // hardcoded status messages such as "Waiting for speech...".
        guard let preview, preview != lastPartialText else { return }
        lastPartialText = preview
        text = corrector.correct(
            preview,
        )
    }

    private func stop(
        completion: DSpeechCompletion,
    ) async -> DSpeechTranscript? {
        guard let sessionID = session.activeID else { return lastTranscript }
        guard let processor = audioProcessor, let stream = streamTranscriber else { return cancel() }
        guard session.beginFinalization(
            for: sessionID,
        ) else { return lastTranscript }

        let pendingStream = streamTask
        processor.stopRecording()
        stopMeter()
        DSpeechAudioSession.deactivate()
        recordingStatus = .transcribing
        await stream.stopStreamTranscription()
        pendingStream?.cancel()
        await pendingStream?.value
        guard session.acceptsResult(
            for: sessionID,
        ), session.isFinalizing else { return nil }

        let samples = Array(
            processor.audioSamples,
        )
        processor.purgeAudioSamples(
            keepingLast: 0,
        )
        let fallbackText = lastPartialText
        audioProcessor = nil
        streamTranscriber = nil
        streamTask = nil
        let task = Task<DSpeechWhisperKitTranscription, Error> {
            try await modelStore.performInference { model in
                try await DSpeechWhisperKitTranscription.transcribe(
                    model: model,
                    audioArray: samples,
                    language: self.locale.language.languageCode?.identifier ?? self.locale.identifier,
                )
            }
        }
        transcriptionTask = task
        let rawText: String
        let decodingSpans: [DSpeechDecodingSpan]
        let resultCompletion: DSpeechCompletion
        do {
            let transcription = try await task.value
            rawText = transcription.rawText
            decodingSpans = transcription.decodingSpans
            resultCompletion = completion
        } catch {
            // A failed final pass retains the preview for review without evidence
            // that would permit automatic application.
            rawText = fallbackText
            decodingSpans = []
            resultCompletion = .failed
        }
        guard session.finish(
            for: sessionID,
        ) else { return nil }
        transcriptionTask = nil
        let correctedText = corrector.correct(
            rawText,
        )
        let transcript = DSpeechTranscript(
            rawText: rawText,
            correctedText: correctedText,
            locale: locale,
            engine: .whisperKit,
            completion: resultCompletion,
            decodingSpans: decodingSpans,
        )
        text = correctedText.isEmpty ? nil : correctedText
        lastTranscript = transcript
        recordingStatus = .stopped
        return transcript
    }

    private func startMeter(
        for sessionID: UUID,
    ) {
        meterTimer = Timer.scheduledTimer(
            withTimeInterval: 0.05,
            repeats: true,
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, session.acceptsResult(
                    for: sessionID,
                ), !session.isFinalizing,
                let processor = audioProcessor else { return }
                guard processor.isRecording else {
                    _ = await stop(
                        completion: .interrupted,
                    )
                    return
                }
                audioMeter = min(
                    max(
                        processor.relativeEnergy.last ?? 0,
                        0,
                    ),
                    1,
                )
            }
        }
    }

    private func stopMeter() {
        meterTimer?.invalidate()
        meterTimer = nil
        audioMeter = 0
    }

    private func failSession(
        _ sessionID: UUID,
    ) {
        guard session.acceptsResult(
            for: sessionID,
        ), !session.isFinalizing else { return }
        let rawText = lastPartialText
        _ = cancel()
        lastTranscript = DSpeechTranscript(
            rawText: rawText,
            correctedText: corrector.correct(
                rawText,
            ),
            locale: locale,
            engine: .whisperKit,
            completion: .failed,
        )
    }
}
