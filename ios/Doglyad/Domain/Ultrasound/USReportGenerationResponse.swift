import Foundation

struct USReportGenerationResponse: Decodable, Sendable {
    let modelId: String
    let generationId: UUID
    let status: USReportGenerationServerStatus
    let sequence: Int
    let partialReport: USReportPreviewResponse
    let report: USExaminationModelReport?
    let errorCode: String?

    init(
        modelId: String,
        generationId: UUID,
        status: USReportGenerationServerStatus,
        sequence: Int,
        partialReport: USReportPreviewResponse,
        report: USExaminationModelReport?,
        errorCode: String?,
    ) {
        self.modelId = modelId
        self.generationId = generationId
        self.status = status
        self.sequence = sequence
        self.partialReport = partialReport
        self.report = report
        self.errorCode = errorCode
    }
}
