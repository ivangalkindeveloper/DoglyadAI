import DoglyadDatabase
import Foundation

final class SharedRepository: SharedRepositoryProtocol {
    let database: DDatabaseProtocol

    init(
        database: DDatabaseProtocol,
    ) {
        self.database = database
    }
}

// MARK: OnBoarding -

extension SharedRepository {
    func isOnBoardingCompleted() -> Bool {
        database.getOnBoardingCompleted()
    }

    func setOnBoardingCompleted(
        value: Bool,
    ) {
        database.setOnBoardingCompleted(
            value: value,
        )
    }
}

// MARK: Legal -

extension SharedRepository {
    func getAcceptedLegalDocumentDate() -> Date? {
        database.getAcceptedLegalDocumentDate()
    }

    func getLegalAcceptedAt() -> Date? {
        database.getLegalAcceptedAt()
    }

    func acceptLegal(
        documentDate: Date,
    ) {
        database.setAcceptedLegal(
            documentDate: documentDate,
            acceptedAt: Date(),
        )
    }
}
