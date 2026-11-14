import Foundation

struct USExaminationReadyMadeTemplate: Codable, Identifiable, Equatable {
    let id: String
    let examinationType: String
    let title: String
    let content: String

    init(
        id: String,
        examinationType: String,
        title: String,
        content: String,
    ) {
        self.id = id
        self.examinationType = examinationType
        self.title = title
        self.content = content
    }

    var localizedTitle: LocalizedStringResource {
        LocalizedStringResource(
            stringLiteral: title,
        )
    }
}
