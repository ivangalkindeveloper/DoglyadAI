import Foundation

struct HistoryDaySection: Identifiable {
    let day: Date
    let title: String
    var reports: [USExaminationReport]

    init(
        day: Date,
        title: String,
        reports: [USExaminationReport],
    ) {
        self.day = day
        self.title = title
        self.reports = reports
    }

    var id: Date {
        day
    }
}
