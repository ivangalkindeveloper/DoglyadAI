@MainActor
final class TemplateEditDeleteLoadingState: TemplateEditStateProtocol, @MainActor Equatable {
    static func == (
        _: TemplateEditDeleteLoadingState,
        _: TemplateEditDeleteLoadingState,
    ) -> Bool {
        true
    }
}
