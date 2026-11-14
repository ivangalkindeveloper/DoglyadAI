import Foundation

struct USReportGenerationRequest: Codable {
    let requestId: UUID
    let examination: USExaminationRequest
    let replacesGenerationId: UUID?

    init(
        requestId: UUID,
        examination: USExaminationRequest,
        replacesGenerationId: UUID?,
    ) {
        self.requestId = requestId
        self.examination = examination
        self.replacesGenerationId = replacesGenerationId
    }
}
