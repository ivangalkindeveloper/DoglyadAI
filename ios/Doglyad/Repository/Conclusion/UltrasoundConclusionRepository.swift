import DoglyadDatabase
import DoglyadNetwork
import Foundation

final class UltrasoundConclusionRepository: UltrasoundConclusionRepositoryProtocol {
    let database: DDatabaseProtocol
    let httpClient: DHttpClientProtocol

    init(
        database: DDatabaseProtocol,
        httpClient: DHttpClientProtocol
    ) {
        self.database = database
        self.httpClient = httpClient
    }
}

// MARK: ExaminationType -

extension UltrasoundConclusionRepository {
    func getSelectedExaminationTypeId() -> String? {
        database.getSelectedUSExaminationTypeId()
    }

    func setSelectedExaminationTypeId(
        id: String
    ) {
        database.setSelectedUSExaminationTypeId(
            value: id
        )
    }
}

// MARK: Conclusion -

extension UltrasoundConclusionRepository {
    static let conclusionEndpoint: String = "/ultrasound_conclusion"

    func generateConclusion(
        locale: Locale,
        request: USExaminationRequest,
        scanPhotoEncodingOptions: ScanPhotoEncodingOptions
    ) async throws -> USExaminationModelConclusion {
        try await httpClient.post(
            endPoint: Self.conclusionEndpoint,
            body: request,
            headers: [
                DHttpHeader.acceptLanguage: locale.identifier,
            ],
            encoderUserInfo: [
                .scanPhotoEncodingOptions: scanPhotoEncodingOptions,
            ]
        )
    }

    func getConclusions(
        limit: Int,
        offset: Int
    ) async -> [USExaminationConclusion] {
        await database.examinationConclusions.fetchExaminationConclusions(
            limit: limit,
            offset: offset
        ) { models in
            models.map { USExaminationConclusion.fromDB($0) }
        }
    }

    func getConclusionsCount() async -> Int {
        await database.examinationConclusions.fetchExaminationConclusionsCount()
    }

    func setConclusion(
        conclusion: USExaminationConclusion
    ) async {
        try? await database.examinationConclusions.setExaminationConclusion(
            value: conclusion.toDB()
        )
    }

    func updateConclusion(
        conclusion: USExaminationConclusion
    ) async {
        try? await database.examinationConclusions.updateExaminationConclusion(
            value: conclusion.toDB()
        )
    }

    func clearAllConclusions() async {
        try? await database.examinationConclusions.clearAllExaminationConclusions()
    }
}

// MARK: Common -

extension UltrasoundConclusionRepository {
    @MainActor func clearAll() async {
        await database.clearAll()
    }
}
