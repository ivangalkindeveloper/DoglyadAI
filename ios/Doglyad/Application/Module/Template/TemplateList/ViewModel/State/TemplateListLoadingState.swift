@MainActor
final class TemplateListLoadingState: TemplateListStateProtocol, @MainActor Equatable {
    static func == (
        _: TemplateListLoadingState,
        _: TemplateListLoadingState,
    ) -> Bool {
        true
    }
}
