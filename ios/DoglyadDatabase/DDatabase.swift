import Foundation
import SwiftData

public final class DDatabase: DDatabaseProtocol {
    let defaults: UserDefaults = .standard
    var container: ModelContainer
    public let examinationReports: DExaminationReportsStore
    public let examinationTemplates: DExaminationTemplatesStore
    public let examinationDraft: DExaminationDraftStore

    public init() throws {
        let schema = Schema(
            [
                NeuralModelSettingsDB.self,
                USExaminationReportDB.self,
                USExaminationDataDB.self,
                USExaminationScanPhotoDB.self,
                USExaminationModelReportDB.self,
                USExaminationPhotoRemarksDB.self,
                USExaminationPhotoRemarkPointDB.self,
                USExaminationTemplateDB.self,
                USExaminationDraftDB.self,
                USExaminationDraftPhotoDB.self,
            ],
        )
        container = try ModelContainer(
            for: schema,
        )
        examinationReports = DExaminationReportsStore(
            modelContainer: container,
        )
        examinationTemplates = DExaminationTemplatesStore(
            modelContainer: container,
        )
        examinationDraft = DExaminationDraftStore(
            modelContainer: container,
        )
    }
}

extension DDatabase: DDatabaseClearProtocol, DDatabaseLegalProtocol, DDatabaseNeuralModelSettingsProtocol, DDatabaseOnBoardingProtocol, DDatabaseUSExaminationNeuralModelProtocol, DDatabaseUSExaminationTemplateProtocol, DDatabaseUSExaminationTypeProtocol, DDatabaseUserSettingsProtocol {
    func getBool(
        _ key: DUserDefaultsKey,
    ) -> Bool {
        defaults.bool(
            forKey: key.rawValue,
        )
    }

    func getString(
        _ key: DUserDefaultsKey,
    ) -> String? {
        defaults.string(
            forKey: key.rawValue,
        )
    }

    func getInt(
        _ key: DUserDefaultsKey,
    ) -> Int? {
        defaults.object(
            forKey: key.rawValue,
        ) as? Int
    }

    func getDouble(
        _ key: DUserDefaultsKey,
    ) -> Double? {
        guard defaults.object(
            forKey: key.rawValue,
        ) != nil else { return nil }
        return defaults.double(
            forKey: key.rawValue,
        )
    }

    func setValue(
        _ value: some Any,
        _ key: DUserDefaultsKey,
    ) {
        defaults.set(
            value,
            forKey: key.rawValue,
        )
    }

    func removeValue(
        _ key: DUserDefaultsKey,
    ) {
        defaults.removeObject(
            forKey: key.rawValue,
        )
    }

    public func clearAll() async throws {
        try await examinationReports.clearAllExaminationReports()
        try await examinationTemplates.clearAllExaminationTemplates()
        try await examinationDraft.clearDraft()
        for key in DUserDefaultsKey.allCases {
            removeValue(
                key,
            )
        }
    }

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

    public func getNeuralModelIsMarkdown() -> Bool {
        getBool(
            .neuralModelIsMarkdown,
        )
    }

    public func setNeuralModelIsMarkdown(
        isMarkdown: Bool,
    ) {
        setValue(
            isMarkdown,
            .neuralModelIsMarkdown,
        )
    }

    public func getNeuralModelTemperature() -> Double? {
        getDouble(
            .neuralModelTemperature,
        )
    }

    public func setNeuralModelTemperature(
        value: Double?,
    ) {
        if let value {
            setValue(
                value,
                .neuralModelTemperature,
            )
        } else {
            removeValue(
                .neuralModelTemperature,
            )
        }
    }

    public func getNeuralModelMaxTokens() -> Int? {
        getInt(
            .neuralModelMaxTokens,
        )
    }

    public func setNeuralModelMaxTokens(
        value: Int?,
    ) {
        if let value {
            setValue(
                value,
                .neuralModelMaxTokens,
            )
        } else {
            removeValue(
                .neuralModelMaxTokens,
            )
        }
    }

    public func getOnBoardingCompleted() -> Bool {
        getBool(
            .isOnBoardingCompleted,
        )
    }

    public func setOnBoardingCompleted(
        isCompleted: Bool,
    ) {
        setValue(
            isCompleted,
            .isOnBoardingCompleted,
        )
    }

    public func getSelectedUSExaminationNeuralModelId() -> String? {
        getString(
            .selectedUSExaminationNeuralModelId,
        )
    }

    public func setSelectedUSExaminationNeuralModelId(
        value: String,
    ) {
        setValue(
            value,
            .selectedUSExaminationNeuralModelId,
        )
    }

    public func getSelectedUSExaminationTemplateId() -> UUID? {
        guard let value = getString(
            .selectedUSExaminationTemplateId,
        ) else { return nil }
        return UUID(
            uuidString: value,
        )
    }

    public func setSelectedUSExaminationTemplateId(
        value: UUID,
    ) {
        setValue(
            value.uuidString,
            .selectedUSExaminationTemplateId,
        )
    }

    public func removeSelectedUSExaminationTemplateId() {
        removeValue(
            .selectedUSExaminationTemplateId,
        )
    }

    public func getSelectedUSExaminationTypeId() -> String? {
        getString(
            .selectedUSExaminationTypeId,
        )
    }

    public func setSelectedUSExaminationTypeId(
        value: String,
    ) {
        setValue(
            value,
            .selectedUSExaminationTypeId,
        )
    }

    public func getRecentUSExaminationTypeIds() -> [String] {
        defaults.stringArray(
            forKey: DUserDefaultsKey.recentUSExaminationTypeIds.rawValue,
        ) ?? []
    }

    public func setRecentUSExaminationTypeIds(
        values: [String],
    ) {
        setValue(
            values,
            .recentUSExaminationTypeIds,
        )
    }

    public func getIsPhotoRemarks() -> Bool {
        getUserSettingsFlag(
            .isPhotoRemarks,
        )
    }

    public func setIsPhotoRemarks(
        isEnabled: Bool,
    ) {
        setValue(
            isEnabled,
            .isPhotoRemarks,
        )
    }

    public func getIsDescriptionRemarks() -> Bool {
        getUserSettingsFlag(
            .isDescriptionRemarks,
        )
    }

    public func setIsDescriptionRemarks(
        isEnabled: Bool,
    ) {
        setValue(
            isEnabled,
            .isDescriptionRemarks,
        )
    }

    public func getIsRemarksVisible() -> Bool {
        getUserSettingsFlag(
            .isRemarksVisible,
        )
    }

    public func setIsRemarksVisible(
        isVisible: Bool,
    ) {
        setValue(
            isVisible,
            .isRemarksVisible,
        )
    }

    private func getUserSettingsFlag(
        _ key: DUserDefaultsKey,
    ) -> Bool {
        guard defaults.object(
            forKey: key.rawValue,
        ) != nil else { return true }
        return getBool(
            key,
        )
    }

    public func getUserEmail() -> String? {
        getString(
            .userEmail,
        )
    }

    public func setUserEmail(
        value: String?,
    ) {
        if let value {
            setValue(
                value,
                .userEmail,
            )
        } else {
            removeValue(
                .userEmail,
            )
        }
    }

    public func getIsRecommendationsIncluded() -> Bool {
        guard defaults.object(
            forKey: DUserDefaultsKey.isRecommendationsIncluded.rawValue,
        ) != nil else {
            return true
        }
        return getBool(
            .isRecommendationsIncluded,
        )
    }

    public func setIsRecommendationsIncluded(
        isIncluded: Bool,
    ) {
        setValue(
            isIncluded,
            .isRecommendationsIncluded,
        )
    }
}
