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
    var plainText: String {
        var sections = [
            "\(String(localized: .reportDescriptionTitle))\n\(description)",
            "\(String(localized: .reportConclusionTitle))\n\(conclusion)",
        ]
        if let recommendations, !recommendations.isEmpty {
            sections.append("\(String(localized: .reportRecommendationsTitle))\n\(recommendations)")
        }
        return sections.joined(separator: "\n\n")
    }

    var markdownText: String {
        var sections = [
            "## \(String(localized: .reportDescriptionTitle))\n\(description)",
            "## \(String(localized: .reportConclusionTitle))\n\(conclusion)",
        ]
        if let recommendations, !recommendations.isEmpty {
            sections.append("## \(String(localized: .reportRecommendationsTitle))\n\(recommendations)")
        }
        return sections.joined(separator: "\n\n")
    }

    static func fromDB(
        _ db: USExaminationModelReportDB
    ) -> USExaminationModelReport {
        USExaminationModelReport(
            id: db.id,
            date: db.date,
            modelId: db.modelId,
            description: db.reportDescription,
            conclusion: db.conclusion,
            recommendations: db.recommendations
        )
    }

    func toDB() -> USExaminationModelReportDB {
        USExaminationModelReportDB(
            id: id,
            date: date,
            modelId: modelId,
            description: description,
            conclusion: conclusion,
            recommendations: recommendations
        )
    }
}
