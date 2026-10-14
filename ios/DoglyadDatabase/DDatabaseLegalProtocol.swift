import Foundation

public protocol DDatabaseLegalProtocol: AnyObject {
    /// The revision date of the legal documents the user accepted.
    /// nil — consent has not been recorded yet.
    func getAcceptedLegalDocumentDate() -> Date?

    /// The moment the user accepted that revision.
    func getLegalAcceptedAt() -> Date?

    func setAcceptedLegal(
        documentDate: Date,
        acceptedAt: Date,
    )
}
