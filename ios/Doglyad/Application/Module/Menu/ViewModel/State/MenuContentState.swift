import Foundation

@MainActor
final class MenuContentState: MenuStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: MenuContentState,
        _: MenuContentState,
    ) -> Bool {
        true
    }
}
