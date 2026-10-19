import Foundation
import SwiftData

@Model
public final class USExaminationReportDB {
    public var id: UUID
    public var date: Date
    public var settingsAI: SettingsAIDB
    public var examinationData: USExaminationDataDB
    @Relationship(
        deleteRule: .cascade,
    ) public var actualModelReport: USExaminationModelReportDB
    @Relationship(
        deleteRule: .cascade,
    ) public var previousModelReports: [USExaminationModelReportDB]

    public init(
        id: UUID = UUID(),
        date: Date,
        settingsAI: SettingsAIDB,
        examinationData: USExaminationDataDB,
        actualModelReport: USExaminationModelReportDB,
        previousModelReports: [USExaminationModelReportDB],
    ) {
        self.id = id
        self.date = date
        self.settingsAI = settingsAI
        self.examinationData = examinationData
        self.actualModelReport = actualModelReport
        self.previousModelReports = previousModelReports
    }
}
