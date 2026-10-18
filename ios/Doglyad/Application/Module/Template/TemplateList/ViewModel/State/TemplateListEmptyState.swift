@MainActor
final class TemplateListEmptyState: TemplateListStateProtocol, @MainActor Equatable {
    static func == (
        _: TemplateListEmptyState,
        _: TemplateListEmptyState,
    ) -> Bool {
        true
    }
}
