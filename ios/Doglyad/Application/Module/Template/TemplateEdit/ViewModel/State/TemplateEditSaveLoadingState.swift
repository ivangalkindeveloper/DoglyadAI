@MainActor
final class TemplateEditSaveLoadingState: TemplateEditStateProtocol, @MainActor Equatable {
    static func == (
        _: TemplateEditSaveLoadingState,
        _: TemplateEditSaveLoadingState,
    ) -> Bool {
        true
    }
}
