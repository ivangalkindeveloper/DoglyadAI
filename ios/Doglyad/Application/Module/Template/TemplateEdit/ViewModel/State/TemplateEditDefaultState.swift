import Foundation

@MainActor
final class TemplateEditDefaultState: TemplateEditStateProtocol, @MainActor Equatable {
    static func == (
        _: TemplateEditDefaultState,
        _: TemplateEditDefaultState,
    ) -> Bool {
        true
    }
}
