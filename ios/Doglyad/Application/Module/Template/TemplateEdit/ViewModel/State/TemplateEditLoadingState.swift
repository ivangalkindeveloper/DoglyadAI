import Foundation

@MainActor
final class TemplateEditLoadingState: TemplateEditStateProtocol, @MainActor Equatable {
    static func == (
        _: TemplateEditLoadingState,
        _: TemplateEditLoadingState,
    ) -> Bool {
        true
    }
}
