import DoglyadDatabase
import Foundation

struct USExaminationModelReport: Identifiable, Codable, Sendable {
    var id: UUID = .init()
    let date: Date
    let modelId: String
    let description: String
    let conclusion: String
    let recommendations: String?
}

private extension USExaminationModelReport {
    enum CodingKeys: String, CodingKey {
        case date,
             modelId,
             description,
             conclusion,
             recommendations
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
        if let recommendations, !recommendations.isEmpty {
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
        if let recommendations, !recommendations.isEmpty {
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
        )
    }
}
