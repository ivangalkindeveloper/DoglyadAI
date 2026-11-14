import Foundation

struct USExaminationType: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let contextualStrings: [String]

    init(
        id: String,
        title: String,
        contextualStrings: [String],
    ) {
        self.id = id
        self.title = title
        self.contextualStrings = contextualStrings
    }

    var localizedTitle: LocalizedStringResource {
        LocalizedStringResource(
            stringLiteral: title,
        )
    }
}
