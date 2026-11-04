enum USReportGenerationServerStatus: String, Decodable, Sendable {
    case queued, generating, completed, failed, cancelled
}
