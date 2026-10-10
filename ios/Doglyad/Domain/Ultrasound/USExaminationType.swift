import Foundation

struct USExaminationType: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let contextualStrings: [String]

    var localizedTitle: LocalizedStringResource {
        LocalizedStringResource(
            stringLiteral: title,
        )
    }
}
