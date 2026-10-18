@MainActor
final class SelectTemplateContentState: SelectTemplateStateProtocol, @MainActor Equatable {
    static func == (
        _: SelectTemplateContentState,
        _: SelectTemplateContentState,
    ) -> Bool {
        true
    }
}
