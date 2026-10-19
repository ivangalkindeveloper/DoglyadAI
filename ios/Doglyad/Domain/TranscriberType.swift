import DoglyadSpeech

enum TranscriberType: String, Codable, CaseIterable, Sendable {
    case sfSpeechRecognizer
    case speechAnalyzer
    case whisperKit

    init(
        engine: DSpeechEngine,
    ) {
        switch engine {
        case .sfSpeechRecognizer: self = .sfSpeechRecognizer
        case .speechAnalyzer: self = .speechAnalyzer
        case .whisperKit: self = .whisperKit
        }
    }
}

extension TranscriberType {
    var speechEngine: DSpeechEngine {
        switch self {
        case .sfSpeechRecognizer: .sfSpeechRecognizer
        case .speechAnalyzer: .speechAnalyzer
        case .whisperKit: .whisperKit
        }
    }

    var titleKey: L10NKey {
        switch self {
        case .sfSpeechRecognizer: .selectTranscriberSFSpeechRecognizerTitle
        case .speechAnalyzer: .selectTranscriberSpeechAnalyzerTitle
        case .whisperKit: .selectTranscriberWhisperKitTitle
        }
    }

    var descriptionKey: L10NKey {
        switch self {
        case .sfSpeechRecognizer: .selectTranscriberSFSpeechRecognizerDescription
        case .speechAnalyzer: .selectTranscriberSpeechAnalyzerDescription
        case .whisperKit: .selectTranscriberWhisperKitDescription
        }
    }
}
