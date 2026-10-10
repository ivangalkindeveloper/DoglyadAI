import Foundation
import Speech

/// Replays a file through the local classic recognizer. This adapter never permits
/// Speech to send the audio to Apple servers.
@MainActor
public final class DSpeechFileRecognizerSFSpeechRecognizer {
    private var task: SFSpeechRecognitionTask?
    private var timeoutTask: Task<Void, Never>?
    private var continuation: CheckedContinuation<String, any Error>?

    public init() {}

    public func transcribe(
        fileURL: URL,
        locale: Locale,
        contextualStrings: [String],
        useHints: Bool = true,
        useCorrection: Bool = true,
        lexiconLocalization: DSpeechLexiconLocalization,
    ) async throws -> DSpeechFileTranscription {
        let authorization: SFSpeechRecognizerAuthorizationStatus = switch SFSpeechRecognizer.authorizationStatus() {
        case .notDetermined:
            await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(
                        returning: status,
                    )
                }
            }
        case .authorized:
            .authorized
        case .denied:
            .denied
        case .restricted:
            .restricted
        @unknown default:
            .restricted
        }
        switch authorization {
        case .authorized:
            break
        case .notDetermined, .denied, .restricted:
            throw DSpeechFileTranscriberError.recognitionFailed(
                "Speech recognition authorization: \(authorization.rawValue)",
            )
        @unknown default:
            throw DSpeechFileTranscriberError.recognitionFailed(
                "Speech recognition authorization: \(authorization.rawValue)",
            )
        }
        guard let recognizer = SFSpeechRecognizer(
            locale: locale,
        ),
            recognizer.isAvailable,
            recognizer.supportsOnDeviceRecognition
        else {
            throw DSpeechFileTranscriberError.onDeviceRecognitionUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(
            url: fileURL,
        )
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        request.addsPunctuation = true
        request.taskHint = .dictation
        request.contextualStrings = useHints ? contextualStrings : []

        let rawText = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, any Error>) in
            self.continuation = continuation
            self.task = recognizer.recognitionTask(
                with: request,
            ) { [weak self] result, error in
                let finalText = result?.isFinal == true ? result?.bestTranscription.formattedString : nil
                let failure = error.map { String(
                    describing: $0,
                ) }
                Task { @MainActor [weak self] in
                    if let finalText {
                        self?.finish(
                            .success(
                                finalText,
                            ),
                        )
                    } else if let failure {
                        self?.finish(
                            .failure(
                                DSpeechFileTranscriberError.recognitionFailed(
                                    failure,
                                ),
                            ),
                        )
                    }
                }
            }
            self.timeoutTask = Task { @MainActor [weak self] in
                try? await Task.sleep(
                    for: .seconds(
                        30,
                    ),
                )
                self?.finish(
                    .failure(
                        DSpeechFileTranscriberError.recognitionTimedOut,
                    ),
                )
            }
        }
        let correctedText = useCorrection
            ? DSpeechLexiconCorrector(
                terms: contextualStrings,
                localization: lexiconLocalization,
            ).correct(
                rawText,
            )
            : rawText
        return DSpeechFileTranscription(
            rawText: rawText,
            correctedText: correctedText,
        )
    }

    private func finish(
        _ result: Result<String, any Error>,
    ) {
        guard let continuation else { return }
        self.continuation = nil
        task?.cancel()
        task = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        continuation.resume(
            with: result,
        )
    }
}
