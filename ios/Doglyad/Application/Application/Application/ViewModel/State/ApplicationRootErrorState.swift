@MainActor
final class ApplicationRootErrorState: ApplicationRootStateProtocol, @MainActor Equatable {
    let id = ApplicationRootViewType.error
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    static func == (
        lhs: ApplicationRootErrorState,
        rhs: ApplicationRootErrorState,
    ) -> Bool {
        lhs === rhs || lhs.id == rhs.id
            && lhs.error.isEqual(
                to: rhs.error,
            )
    }
}
