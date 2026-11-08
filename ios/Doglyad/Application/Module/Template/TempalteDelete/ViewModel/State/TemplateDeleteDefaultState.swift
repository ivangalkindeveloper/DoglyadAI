@MainActor
final class TemplateDeleteDefaultState: TemplateDeleteStateProtocol, @MainActor Equatable {
    static func == (
        _: TemplateDeleteDefaultState,
        _: TemplateDeleteDefaultState,
    ) -> Bool {
        true
    }
}
