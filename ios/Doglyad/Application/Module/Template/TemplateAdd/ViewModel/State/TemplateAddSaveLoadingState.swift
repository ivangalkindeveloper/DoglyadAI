@MainActor
final class TemplateAddSaveLoadingState: TemplateAddStateProtocol, @MainActor Equatable {
    static func == (
        _: TemplateAddSaveLoadingState,
        _: TemplateAddSaveLoadingState,
    ) -> Bool {
        true
    }
}
