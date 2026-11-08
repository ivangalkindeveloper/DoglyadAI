@MainActor
final class TemplateAddInitializationLoadingState: TemplateAddStateProtocol, @MainActor Equatable {
    static func == (
        _: TemplateAddInitializationLoadingState,
        _: TemplateAddInitializationLoadingState,
    ) -> Bool {
        true
    }
}
