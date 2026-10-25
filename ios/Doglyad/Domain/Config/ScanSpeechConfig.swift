import Foundation

struct ScanSpeechConfig: Codable, Equatable {
    let transcriptMaxLength: Int
}

extension ScanSpeechConfig {
    // Placeholder configuration for previews/tests before server configuration is loaded.
    static let `default` = ScanSpeechConfig(
        transcriptMaxLength: .max,
    )
}
