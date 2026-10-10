import Foundation

protocol SharedRepositoryProtocol: AnyObject {
    func isOnBoardingCompleted() -> Bool

    func setOnBoardingCompleted(
        value: Bool,
    )

    func getAcceptedLegalDocumentDate() -> Date?

    func getLegalAcceptedAt() -> Date?

    func acceptLegal(
        documentDate: Date,
    )
}
