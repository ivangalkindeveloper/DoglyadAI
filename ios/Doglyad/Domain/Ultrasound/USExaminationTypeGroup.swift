import Foundation

struct USExaminationTypeGroup: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let examinationTypes: [USExaminationType]

    init(
        id: String,
        title: String,
        examinationTypes: [USExaminationType],
    ) {
        self.id = id
        self.title = title
        self.examinationTypes = examinationTypes
    }

    var localizedTitle: LocalizedStringResource {
        LocalizedStringResource(
            stringLiteral: title,
        )
    }
}
