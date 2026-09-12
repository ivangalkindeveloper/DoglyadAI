import Foundation

struct HistoryDaySection: Identifiable {
    let day: Date
    let title: String
    var reports: [USExaminationReport]

    var id: Date { day }
}
