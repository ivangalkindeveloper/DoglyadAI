#if DEBUG && DOGLYAD_REGRESSION
    import Combine
    import DoglyadSpeech
    import Foundation

    /// Supplies a known transcript at the microphone boundary. Parsing and form updates stay real.
    @MainActor
    final class RegressionSpeechController: DSpeechControllerProtocol {
        @Published private(set) var recordingStatus: DSpeechRecordingStatus = .stopped
        @Published private(set) var text: String?
        @Published private(set) var audioMeter: Float = 0
        @Published private(set) var lastTranscript: DSpeechTranscript?
        @Published private(set) var modelPreparationStatus: DSpeechModelPreparationStatus = .checking
        private let locale: Locale
        private let mode: String
        private var generation = 0
        private var preparationAttempts = 0
        private var task: Task<Void, Never>?

        init(
            locale: Locale,
            contextualStrings _: [String],
            lexiconLocalization _: DSpeechLexiconLocalization,
        ) {
            self.locale = locale
            mode = UserDefaults.standard.string(
                forKey: "regressionSpeech",
            ) ?? "review"
        }

        static func make(
            container: DependencyContainer,
        ) -> RegressionSpeechController? {
            let mode = UserDefaults.standard.string(
                forKey: "regressionSpeech",
            ) ?? ""
            guard Bundle.main.bundleIdentifier == "com.medical.doglyad.local", !mode.isEmpty else {
                return nil
            }
            precondition(
                ["review", "prepare-failure", "empty", "cached-model"].contains(
                    mode,
                ),
                "Unknown regressionSpeech mode",
            )
            return RegressionSpeechController(
                locale: container.language.currentLocale,
                contextualStrings: [],
                lexiconLocalization: container.l10n.voice.speech,
            )
        }

        func prepareModel() {
            task?.cancel()
            if mode == "cached-model" {
                modelPreparationStatus = DSpeechWhisperKitModel.shared.isDownloaded ? .ready : .downloading(
                    progress: 0,
                )
                return
            }
            preparationAttempts += 1
            modelPreparationStatus = .loading
            task = Task { [weak self] in
                try? await Task.sleep(
                    for: .milliseconds(
                        500,
                    ),
                )
                guard !Task.isCancelled, let self else {
                    return
                }
                modelPreparationStatus = mode == "prepare-failure" && preparationAttempts == 1 ? .failed : .ready
            }
        }

        func start() {
            guard modelPreparationStatus == .ready, recordingStatus == .stopped else {
                return
            }
            generation += 1
            text = nil
            lastTranscript = nil
            recordingStatus = .recording
            audioMeter = 0.6
        }

        func stop() async -> DSpeechTranscript? {
            guard recordingStatus == .recording else {
                return nil
            }
            let current = generation
            recordingStatus = .transcribing
            audioMeter = 0
            try? await Task.sleep(
                for: .milliseconds(
                    400,
                ),
            )
            guard generation == current else {
                return nil
            }
            let root = URL(
                fileURLWithPath: #filePath,
            )
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            let file = root.appendingPathComponent(
                "backend/main/mock/ru/voice_form.json",
            )
            let fixture = try! JSONDecoder().decode(
                RegressionSpeechFixture.self,
                from: Data(
                    contentsOf: file,
                ),
            )
            let value = mode == "empty" ? "" : fixture.transcript
            let transcript = DSpeechTranscript(
                rawText: value,
                correctedText: value,
                locale: locale,
                engine: .whisperKit,
                completion: .finished,
                decodingSpans: [DSpeechDecodingSpan(
                    utf16Start: 0,
                    utf16Length: value.utf16.count,
                    averageLogProbability: -0.1,
                    temperature: 0,
                    compressionRatio: 1,
                    recheckedText: value,
                    isSpeechDetected: true,
                )],
            )
            text = value
            lastTranscript = transcript
            recordingStatus = .stopped
            return transcript
        }

        func cancel() -> DSpeechTranscript? {
            generation += 1
            task?.cancel()
            recordingStatus = .stopped
            audioMeter = 0
            return nil
        }
    }

    private struct RegressionSpeechFixture: Decodable {
        let transcript: String
    }
#endif
