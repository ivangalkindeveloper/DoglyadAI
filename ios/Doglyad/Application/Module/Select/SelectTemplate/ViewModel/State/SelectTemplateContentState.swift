@MainActor
final class SelectTemplateContentState: SelectTemplateStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: SelectTemplateContentState,
        _: SelectTemplateContentState,
    ) -> Bool {
        true
    }
}
