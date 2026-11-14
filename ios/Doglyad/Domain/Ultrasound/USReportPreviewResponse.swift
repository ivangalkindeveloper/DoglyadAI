struct USReportPreviewResponse: Decodable, Sendable {
    let description: String?
    let conclusion: String?
    let recommendations: String?
    let descriptionRemarks: String?

    init(
        description: String?,
        conclusion: String?,
        recommendations: String?,
        descriptionRemarks: String?,
    ) {
        self.description = description
        self.conclusion = conclusion
        self.recommendations = recommendations
        self.descriptionRemarks = descriptionRemarks
    }
}
