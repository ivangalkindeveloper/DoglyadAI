@MainActor
final class TemplateEditInitializationLoadingState: TemplateEditStateProtocol, @MainActor Equatable {
    static func == (
        _: TemplateEditInitializationLoadingState,
        _: TemplateEditInitializationLoadingState,
    ) -> Bool {
        true
    }
}
