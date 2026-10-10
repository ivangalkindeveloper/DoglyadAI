import Foundation

public enum DSpeechFileTranscriberError: Error, CustomStringConvertible {
    case unsupportedLocale
    case noCompatibleAudioFormat(assetStatus: String, availableFormats: Int)
    case onDeviceRecognitionUnavailable
    case recognitionTimedOut
    case recognitionFailed(String)

    public var description: String {
        switch self {
        case .unsupportedLocale:
            "Unsupported transcription locale"
        case let .noCompatibleAudioFormat(
            assetStatus,
            availableFormats,
        ):
            "No compatible SpeechAnalyzer audio format; asset status: \(assetStatus); available formats: \(availableFormats)"
        case .onDeviceRecognitionUnavailable:
            "On-device speech recognition is unavailable for this locale"
        case .recognitionTimedOut:
            "Speech recognition did not finish in time"
        case let .recognitionFailed(
            reason,
        ):
            "Speech recognition failed: \(reason)"
        }
    }
}
