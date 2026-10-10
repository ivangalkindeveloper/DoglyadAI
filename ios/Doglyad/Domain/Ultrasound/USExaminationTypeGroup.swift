import Foundation

struct USExaminationTypeGroup: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let examinationTypes: [USExaminationType]

    var localizedTitle: LocalizedStringResource {
        LocalizedStringResource(
            stringLiteral: title,
        )
    }
}
