@MainActor
final class SelectTemplateEmptyState: SelectTemplateStateProtocol, @MainActor Equatable {
    static func == (
        _: SelectTemplateEmptyState,
        _: SelectTemplateEmptyState,
    ) -> Bool {
        true
    }
}
