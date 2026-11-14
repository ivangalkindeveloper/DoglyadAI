import Foundation

@MainActor
final class TemplateAddInitialState: TemplateAddStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: TemplateAddInitialState,
        _: TemplateAddInitialState,
    ) -> Bool {
        true
    }
}
