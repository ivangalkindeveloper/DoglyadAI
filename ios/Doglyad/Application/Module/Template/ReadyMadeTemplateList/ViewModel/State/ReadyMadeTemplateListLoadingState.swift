import Foundation

@MainActor
final class ReadyMadeTemplateListLoadingState: ReadyMadeTemplateListStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: ReadyMadeTemplateListLoadingState,
        _: ReadyMadeTemplateListLoadingState,
    ) -> Bool {
        true
    }
}
