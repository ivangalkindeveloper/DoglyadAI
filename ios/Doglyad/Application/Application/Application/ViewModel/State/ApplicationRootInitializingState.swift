@MainActor
final class ApplicationRootInitializingState: ApplicationRootStateProtocol, @MainActor Equatable {
    let id: ApplicationRootViewType
    let previousFailure: ApplicationRootFailedState?

    init(
        previousFailure: ApplicationRootFailedState? = nil,
    ) {
        self.previousFailure = previousFailure
        id = previousFailure?.id ?? .splash
    }

    static func == (
        lhs: ApplicationRootInitializingState,
        rhs: ApplicationRootInitializingState,
    ) -> Bool {
        lhs.id == rhs.id
            && lhs.previousFailure == rhs.previousFailure
    }
}
