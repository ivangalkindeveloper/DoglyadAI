import Foundation

struct HistoryDaySection: Identifiable {
    let day: Date
    let title: String
    var conclusions: [USExaminationConclusion]

    var id: Date { day }
}
