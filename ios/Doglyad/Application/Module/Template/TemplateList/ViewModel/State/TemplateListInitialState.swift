@MainActor
final class TemplateListInitialState: TemplateListStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: TemplateListInitialState,
        _: TemplateListInitialState,
    ) -> Bool {
        true
    }
}
