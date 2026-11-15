import Foundation

@MainActor
protocol MenuStateProtocol: AnyObject {
    var reportsCount: Int? {
        get
    }

    func copyWith(
        reportsCount: Int??,
    ) -> MenuContentState
}
