import Foundation

@MainActor
final class TemplateAddInitialState: TemplateAddStateProtocol, @MainActor Equatable {
    static func == (
        _: TemplateAddInitialState,
        _: TemplateAddInitialState,
    ) -> Bool {
        true
    }
}
