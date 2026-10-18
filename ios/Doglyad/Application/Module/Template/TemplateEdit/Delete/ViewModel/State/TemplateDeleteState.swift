@MainActor
final class TemplateDeleteState: TemplateDeleteStateProtocol, @MainActor Equatable {
    static func == (
        _: TemplateDeleteState,
        _: TemplateDeleteState,
    ) -> Bool {
        true
    }
}
