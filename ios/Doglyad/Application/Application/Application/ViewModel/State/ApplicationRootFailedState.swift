@MainActor
final class ApplicationRootFailedState: ApplicationRootStateProtocol, @MainActor Equatable {
    let id = ApplicationRootViewType.error
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    static func == (
        lhs: ApplicationRootFailedState,
        rhs: ApplicationRootFailedState,
    ) -> Bool {
        lhs === rhs || lhs.id == rhs.id
            && lhs.error.isEqual(
                to: rhs.error,
            )
    }
}
