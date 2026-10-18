import Foundation

@MainActor
final class ReadyMadeTemplateListLoadingState: ReadyMadeTemplateListStateProtocol, @MainActor Equatable {
    static func == (
        _: ReadyMadeTemplateListLoadingState,
        _: ReadyMadeTemplateListLoadingState,
    ) -> Bool {
        true
    }
}
