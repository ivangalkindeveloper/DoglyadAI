@MainActor
final class SelectTemplateLoadingState: SelectTemplateStateProtocol, @MainActor Equatable {
    static func == (
        _: SelectTemplateLoadingState,
        _: SelectTemplateLoadingState,
    ) -> Bool {
        true
    }
}
