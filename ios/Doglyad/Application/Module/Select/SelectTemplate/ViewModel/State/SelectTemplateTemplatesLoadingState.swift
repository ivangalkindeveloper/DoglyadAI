@MainActor
final class SelectTemplateTemplatesLoadingState: SelectTemplateStateProtocol, @MainActor Equatable {
    static func == (
        _: SelectTemplateTemplatesLoadingState,
        _: SelectTemplateTemplatesLoadingState,
    ) -> Bool {
        true
    }
}
