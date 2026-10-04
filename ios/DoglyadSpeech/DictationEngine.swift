@frozen public enum DictationEngine: Sendable {
    case whisperKit
    case speechAnalyzer
    case sfSpeechRecognizer
}
