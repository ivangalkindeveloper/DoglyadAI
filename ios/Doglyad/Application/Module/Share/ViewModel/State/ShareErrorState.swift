import Foundation

@MainActor
final class ShareErrorState: ShareStateProtocol, @MainActor Equatable {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    static func == (
        lhs: ShareErrorState,
        rhs: ShareErrorState,
    ) -> Bool {
        lhs === rhs || lhs.error.isEqual(
            to: rhs.error,
        )
    }
}
