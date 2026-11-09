import Foundation

@MainActor
final class MenuContentState: MenuStateProtocol, @MainActor Equatable {
    static func == (
        _: MenuContentState,
        _: MenuContentState,
    ) -> Bool {
        true
    }
}
