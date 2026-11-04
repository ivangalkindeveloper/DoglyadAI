import Foundation

struct USReportGenerationResponse: Decodable, Sendable {
    let modelId: String
    let generationId: UUID
    let status: USReportGenerationServerStatus
    let sequence: Int
    let partialReport: USReportPreviewResponse
    let report: USExaminationModelReport?
    let errorCode: String?
}
