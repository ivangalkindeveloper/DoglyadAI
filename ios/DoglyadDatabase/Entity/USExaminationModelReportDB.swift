import Foundation
import SwiftData

@Model
public final class USExaminationModelReportDB {
    public var id: UUID
    public var date: Date
    public var modelId: String
    public var reportDescription: String = ""
    @Attribute public var conclusion: String
    public var recommendations: String?

    public init(
        id: UUID = UUID(),
        date: Date,
        modelId: String,
        description: String,
        conclusion: String,
        recommendations: String?
    ) {
        self.id = id
        self.date = date
        self.modelId = modelId
        reportDescription = description
        self.conclusion = conclusion
        self.recommendations = recommendations
    }
}
