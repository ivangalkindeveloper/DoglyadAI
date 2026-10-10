import AVFoundation
import Combine
import Foundation
import WhisperKit

/// Records uncompressed audio and runs the selected Whisper Turbo model on the device.
@MainActor
public final class DSpeechControllerWhisperKit: DSpeechControllerProtocol {
    private let locale: Locale
    private let corrector: DSpeechLexiconCorrector
    private let modelStore = DSpeechWhisperKitModel.shared
    private var modelCancellable: AnyCancellable?
    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var audioURL: URL?
    private var transcriptionTask: Task<DSpeechWhisperKitTranscription, Error>?
    private var session = DSpeechSessionGate()

    @Published public private(set) var status: DSpeechRecordingStatus = .stopped
    @Published public private(set) var text: String?
    @Published public private(set) var audioMeter: Float = 0
    @Published public private(set) var lastTranscript: DSpeechTranscript?
    @Published public private(set) var modelPreparation: DSpeechModelPreparation = .checking

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
            self?.modelPreparation = state
        }
    }

    public func prepareModel() {
        modelStore.prepare()
    }

    public func start() {
        switch status {
        case .stopped:
            break
        case .preparing, .recording, .transcribing:
            return
        }
        guard case .ready = modelPreparation else { return }
        guard let sessionID = session.start() else { return }

        removeStaleRecordings()
        status = .preparing
        text = nil
        lastTranscript = nil
        audioMeter = 0
        do {
            try beginRecording()
        } catch {
            failSession(
                sessionID,
            )
        }
    }

    @discardableResult
    public func stop() async -> DSpeechTranscript? {
        await stop(
            completion: .finished,
        )
    }

    private func stop(
        completion: DSpeechCompletion,
    ) async -> DSpeechTranscript? {
        guard let sessionID = session.activeID,
              session.beginFinalization(
                  for: sessionID,
              ),
              let recorder,
              let audioURL else { return lastTranscript }

        let duration = recorder.currentTime
        recorder.stop()
        self.recorder = nil
        stopMeter()
        DSpeechAudioSession.deactivate()
        status = .transcribing
        defer {
            try? FileManager.default.removeItem(
                at: audioURL,
            )
            if self.audioURL == audioURL {
                self.audioURL = nil
            }
        }

        let task = Task<DSpeechWhisperKitTranscription, Error> {
            let model = try await modelStore.load()
            let language = locale.language.languageCode?.identifier ?? locale.identifier
            return try await DSpeechWhisperKitTranscription.transcribe(
                model: model,
                audioPath: audioURL.path,
                language: language,
                duration: duration,
            )
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
            rawText = ""
            decodingSpans = []
            resultCompletion = .failed
        }
        transcriptionTask = nil
        guard session.finish(
            for: sessionID,
        ) else { return nil }

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
        status = .stopped
        return transcript
    }

    @discardableResult
    public func cancel() -> DSpeechTranscript? {
        guard session.cancel() != nil else { return lastTranscript }

        transcriptionTask?.cancel()
        recorder?.stop()
        recorder = nil
        stopMeter()
        DSpeechAudioSession.deactivate()
        if transcriptionTask == nil, let audioURL {
            try? FileManager.default.removeItem(
                at: audioURL,
            )
            self.audioURL = nil
        }
        audioMeter = 0
        status = .stopped
        return nil
    }

    private func beginRecording() throws {
        try DSpeechAudioSession.activate()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "doglyad-dictation-\(UUID().uuidString).caf",
            )
        audioURL = url
        let settings: [String: Any] = [
            AVFormatIDKey: Int(
                kAudioFormatLinearPCM,
            ),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        let recorder = try AVAudioRecorder(
            url: url,
            settings: settings,
        )
        recorder.isMeteringEnabled = true
        guard recorder.record() else {
            throw DSpeechError.unavailable
        }
        self.recorder = recorder
        status = .recording
        meterTimer = Timer.scheduledTimer(
            withTimeInterval: 0.05,
            repeats: true,
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let recorder = self.recorder else { return }
                guard recorder.isRecording else {
                    _ = await stop(
                        completion: .interrupted,
                    )
                    return
                }
                recorder.updateMeters()
                let amplitude = pow(
                    10,
                    recorder.averagePower(
                        forChannel: 0,
                    ) / 20,
                )
                audioMeter = min(
                    max(
                        amplitude * 15,
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

    private func removeStaleRecordings() {
        let directory = FileManager.default.temporaryDirectory
        let cutoff = Date().addingTimeInterval(
            -3600,
        )
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
        ) else { return }
        for file in files where file.lastPathComponent.hasPrefix(
            "doglyad-dictation-",
        )
            && file.pathExtension == "caf"
        {
            if let modified = try? file.resourceValues(
                forKeys: [.contentModificationDateKey],
            )
            .contentModificationDate, modified < cutoff {
                try? FileManager.default.removeItem(
                    at: file,
                )
            }
        }
    }

    private func failSession(
        _ sessionID: UUID,
    ) {
        guard session.cancel() == sessionID else { return }
        recorder?.stop()
        recorder = nil
        stopMeter()
        DSpeechAudioSession.deactivate()
        if let audioURL {
            try? FileManager.default.removeItem(
                at: audioURL,
            )
            self.audioURL = nil
        }
        lastTranscript = DSpeechTranscript(
            rawText: "",
            correctedText: "",
            locale: locale,
            engine: .whisperKit,
            completion: .failed,
        )
        status = .stopped
    }
}
