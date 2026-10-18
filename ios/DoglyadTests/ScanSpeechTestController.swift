import Combine
import DoglyadSpeech
import Foundation

@MainActor
final class ScanSpeechTestController: DSpeechControllerProtocol {
    @Published var recordingStatus: DSpeechRecordingStatus = .stopped
    @Published var text: String?
    @Published var audioMeter: Float = 0
    var lastTranscript: DSpeechTranscript?

    init(
        locale _: Locale,
        contextualStrings _: [String],
        lexiconLocalization _: DSpeechLexiconLocalization,
    ) {}

    func start() {
        recordingStatus = .recording
    }

    func stop() async -> DSpeechTranscript? {
        recordingStatus = .stopped
        return lastTranscript
    }

    func cancel() -> DSpeechTranscript? {
        recordingStatus = .stopped
        return nil
    }
}
