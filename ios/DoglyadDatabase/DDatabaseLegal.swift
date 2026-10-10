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

extension DDatabase: DDatabaseLegalProtocol {
    public func getAcceptedLegalDocumentDate() -> Date? {
        date(
            for: .acceptedLegalDocumentDate,
        )
    }

    public func getLegalAcceptedAt() -> Date? {
        date(
            for: .legalAcceptedAt,
        )
    }

    public func setAcceptedLegal(
        documentDate: Date,
        acceptedAt: Date,
    ) {
        setValue(
            documentDate.timeIntervalSince1970,
            .acceptedLegalDocumentDate,
        )
        setValue(
            acceptedAt.timeIntervalSince1970,
            .legalAcceptedAt,
        )
    }

    private func date(
        for key: DUserDefaultsKey,
    ) -> Date? {
        guard let interval = getDouble(
            key,
        ) else { return nil }
        return Date(
            timeIntervalSince1970: interval,
        )
    }
}
