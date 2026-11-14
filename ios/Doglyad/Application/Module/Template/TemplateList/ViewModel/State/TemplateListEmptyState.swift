@MainActor
final class TemplateListEmptyState: TemplateListStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: TemplateListEmptyState,
        _: TemplateListEmptyState,
    ) -> Bool {
        true
    }
}
