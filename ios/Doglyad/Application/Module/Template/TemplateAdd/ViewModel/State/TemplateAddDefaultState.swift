import Foundation

@MainActor
final class TemplateAddDefaultState: TemplateAddStateProtocol, @MainActor Equatable {
    static func == (
        _: TemplateAddDefaultState,
        _: TemplateAddDefaultState,
    ) -> Bool {
        true
    }
}
