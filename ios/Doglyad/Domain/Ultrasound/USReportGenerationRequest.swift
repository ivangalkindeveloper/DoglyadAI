import Foundation

struct USReportGenerationRequest: Codable {
    let requestId: UUID
    let examination: USExaminationRequest
    let replacesGenerationId: UUID?
}
