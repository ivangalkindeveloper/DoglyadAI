struct USReportPreviewResponse: Decodable, Sendable {
    let description: String?
    let conclusion: String?
    let recommendations: String?
    let descriptionRemarks: String?
}
