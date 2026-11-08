@MainActor
final class SelectTemplateSelectionLoadingState: SelectTemplateStateProtocol, @MainActor Equatable {
    static func == (
        _: SelectTemplateSelectionLoadingState,
        _: SelectTemplateSelectionLoadingState,
    ) -> Bool {
        true
    }
}
