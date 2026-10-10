import Foundation

struct USExaminationReadyMadeTemplate: Codable, Identifiable, Equatable {
    let id: String
    let examinationType: String
    let title: String
    let content: String

    var localizedTitle: LocalizedStringResource {
        LocalizedStringResource(
            stringLiteral: title,
        )
    }
}
