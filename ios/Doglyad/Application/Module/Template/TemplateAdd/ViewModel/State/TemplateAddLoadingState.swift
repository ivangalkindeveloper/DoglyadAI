import Foundation

@MainActor
final class TemplateAddLoadingState: TemplateAddStateProtocol, @MainActor Equatable {
    static func == (
        _: TemplateAddLoadingState,
        _: TemplateAddLoadingState,
    ) -> Bool {
        true
    }
}
