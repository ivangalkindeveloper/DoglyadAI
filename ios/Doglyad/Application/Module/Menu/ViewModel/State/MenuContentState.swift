import Foundation

@MainActor
final class MenuContentState: MenuStateProtocol, @MainActor Equatable {
    let reportsCount: Int?

    init(
        reportsCount: Int? = nil,
    ) {
        self.reportsCount = reportsCount
    }

    func copyWith(
        reportsCount: Int?? = nil,
    ) -> MenuContentState {
        MenuContentState(
            reportsCount: reportsCount ?? self.reportsCount,
        )
    }

    static func == (
        lhs: MenuContentState,
        rhs: MenuContentState,
    ) -> Bool {
        lhs.reportsCount == rhs.reportsCount
    }
}
