import DoglyadDatabase
import Foundation

struct USExaminationModelReport: Identifiable, Codable, Equatable, Sendable {
    var id: UUID = .init()
    let date: Date
    let modelId: String
    let description: String
    let conclusion: String
    let recommendations: String?
    let descriptionRemarks: String?
    let photoRemarks: [USExaminationPhotoRemarks]

    init(
        id: UUID = UUID(),
        date: Date,
        modelId: String,
        description: String,
        conclusion: String,
        recommendations: String?,
        descriptionRemarks: String? = nil,
        photoRemarks: [USExaminationPhotoRemarks] = [],
    ) {
        self.id = id
        self.date = date
        self.modelId = modelId
        self.description = description
        self.conclusion = conclusion
        self.recommendations = recommendations
        self.descriptionRemarks = descriptionRemarks
        self.photoRemarks = photoRemarks
    }
}

private extension USExaminationModelReport {
    enum CodingKeys: String, CodingKey {
        case date,
             modelId,
             description,
             conclusion,
             recommendations,
             descriptionRemarks,
             photoRemarks
    }
}

extension USExaminationModelReport {
    func plainText(
        l10n: L10N,
    ) -> String {
        var sections = [
            "\(String(localized: l10n[.reportDescriptionTitle]))\n\(description)",
            "\(String(localized: l10n[.reportConclusionTitle]))\n\(conclusion)",
        ]
        if let recommendations {
            sections.append(
                "\(String(localized: l10n[.reportRecommendationsTitle]))\n\(recommendations)",
            )
        }
        return sections.joined(
            separator: "\n\n",
        )
    }

    func markdownText(
        l10n: L10N,
    ) -> String {
        var sections = [
            "## \(String(localized: l10n[.reportDescriptionTitle]))\n\(description)",
            "## \(String(localized: l10n[.reportConclusionTitle]))\n\(conclusion)",
        ]
        if let recommendations {
            sections.append(
                "## \(String(localized: l10n[.reportRecommendationsTitle]))\n\(recommendations)",
            )
        }
        return sections.joined(
            separator: "\n\n",
        )
    }

    static func fromDB(
        _ db: USExaminationModelReportDB,
    ) -> USExaminationModelReport {
        USExaminationModelReport(
            id: db.id,
            date: db.date,
            modelId: db.modelId,
            description: db.reportDescription,
            conclusion: db.conclusion,
            recommendations: db.recommendations,
            descriptionRemarks: db.descriptionRemarks,
            photoRemarks: db.photoRemarks.map { USExaminationPhotoRemarks.fromDB(
                $0,
            ) },
        )
    }

    func toDB() -> USExaminationModelReportDB {
        USExaminationModelReportDB(
            id: id,
            date: date,
            modelId: modelId,
            description: description,
            conclusion: conclusion,
            recommendations: recommendations,
            descriptionRemarks: descriptionRemarks,
            photoRemarks: photoRemarks.map { $0.toDB() },
        )
    }
}
