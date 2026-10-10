import Foundation

extension LocalizedStringResource {
    static func forExaminationTypeById(
        types: [String: USExaminationType],
        id: String,
    ) -> LocalizedStringResource {
        types[
            id,
        ]?.localizedTitle ?? LocalizedStringResource(
            "",
        )
    }
}
