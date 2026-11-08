import Foundation

@MainActor
final class TemplateEditInitialState: TemplateEditStateProtocol, @MainActor Equatable {
    static func == (
        _: TemplateEditInitialState,
        _: TemplateEditInitialState,
    ) -> Bool {
        true
    }
}
