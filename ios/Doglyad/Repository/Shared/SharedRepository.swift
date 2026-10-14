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
    func isOnBoardingCompleted() async throws -> Bool {
        database.getOnBoardingCompleted()
    }

    func setOnBoardingCompleted(
        isCompleted: Bool,
    ) async throws {
        database.setOnBoardingCompleted(
            isCompleted: isCompleted,
        )
    }
}

// MARK: Legal -

extension SharedRepository {
    func getAcceptedLegalDocumentDate() async throws -> Date? {
        database.getAcceptedLegalDocumentDate()
    }

    func getLegalAcceptedAt() async throws -> Date? {
        database.getLegalAcceptedAt()
    }

    func acceptLegal(
        documentDate: Date,
    ) async throws {
        database.setAcceptedLegal(
            documentDate: documentDate,
            acceptedAt: Date(),
        )
    }
}
