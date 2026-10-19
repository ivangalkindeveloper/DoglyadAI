enum TranscriptParserType: String, Codable, CaseIterable, Sendable {
    case foundationModels
    case server
}

extension TranscriptParserType {
    var titleKey: L10NKey {
        switch self {
        case .foundationModels: .selectTranscriptParserFoundationModelsTitle
        case .server: .selectTranscriptParserServerTitle
        }
    }

    var descriptionKey: L10NKey {
        switch self {
        case .foundationModels: .selectTranscriptParserFoundationModelsDescription
        case .server: .selectTranscriptParserServerDescription
        }
    }
}
