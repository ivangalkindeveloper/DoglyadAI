@MainActor
final class TemplateListInitialState: TemplateListStateProtocol, @MainActor Equatable {
    static func == (
        _: TemplateListInitialState,
        _: TemplateListInitialState,
    ) -> Bool {
        true
    }
}
