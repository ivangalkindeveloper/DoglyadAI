import Foundation

struct USReportGeneration: Equatable, Sendable {
    var status: USReportGenerationStatus = .completed
    var id: UUID?
    var requestData: Data?
    var sequence: Int = -1
}
