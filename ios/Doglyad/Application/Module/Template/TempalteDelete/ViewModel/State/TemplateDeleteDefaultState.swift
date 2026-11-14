@MainActor
final class TemplateDeleteDefaultState: TemplateDeleteStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: TemplateDeleteDefaultState,
        _: TemplateDeleteDefaultState,
    ) -> Bool {
        true
    }
}
