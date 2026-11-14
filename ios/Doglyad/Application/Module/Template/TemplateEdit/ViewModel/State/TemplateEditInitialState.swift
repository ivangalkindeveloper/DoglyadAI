import Foundation

@MainActor
final class TemplateEditInitialState: TemplateEditStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: TemplateEditInitialState,
        _: TemplateEditInitialState,
    ) -> Bool {
        true
    }
}
