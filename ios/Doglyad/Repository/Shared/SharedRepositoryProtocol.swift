import Foundation

protocol SharedRepositoryProtocol: AnyObject {
    func isOnBoardingCompleted() async throws -> Bool

    func setOnBoardingCompleted(
        isCompleted: Bool,
    ) async throws

    func getAcceptedLegalDocumentDate() async throws -> Date?

    func getLegalAcceptedAt() async throws -> Date?

    func acceptLegal(
        documentDate: Date,
    ) async throws
}
