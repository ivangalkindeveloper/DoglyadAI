import Foundation
import SwiftData

@Model
public final class USExaminationReportDB {
    public var id: UUID
    public var date: Date
    @Relationship public var neuralModelSettings: NeuralModelSettingsDB
    @Relationship public var examinationData: USExaminationDataDB
    @Relationship public var actualModelReport: USExaminationModelReportDB
    @Relationship public var previousModelReports: [USExaminationModelReportDB]

    public init(
        id: UUID = UUID(),
        date: Date,
        neuralModelSettings: NeuralModelSettingsDB,
        examinationData: USExaminationDataDB,
        actualModelReport: USExaminationModelReportDB,
        previousModelReports: [USExaminationModelReportDB]
    ) {
        self.id = id
        self.date = date
        self.neuralModelSettings = neuralModelSettings
        self.examinationData = examinationData
        self.actualModelReport = actualModelReport
        self.previousModelReports = previousModelReports
    }
}
