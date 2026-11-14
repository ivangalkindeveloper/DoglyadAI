import Foundation

struct USReportGeneration: Equatable, Sendable {
    var status: USReportGenerationStatus = .completed
    var id: UUID?
    var requestData: Data?
    var sequence: Int = -1

    init(
        status: USReportGenerationStatus = .completed,
        id: UUID? = nil,
        requestData: Data? = nil,
        sequence: Int = -1,
    ) {
        self.status = status
        self.id = id
        self.requestData = requestData
        self.sequence = sequence
    }
}
