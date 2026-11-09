@MainActor
final class ApplicationRootLoadingState: ApplicationRootStateProtocol, @MainActor Equatable {
    let id: ApplicationRootViewType
    let previousFailure: ApplicationRootErrorState?

    init(
        previousFailure: ApplicationRootErrorState? = nil,
    ) {
        id = previousFailure?.id ?? .splash
        self.previousFailure = previousFailure
    }

    static func == (
        lhs: ApplicationRootLoadingState,
        rhs: ApplicationRootLoadingState,
    ) -> Bool {
        lhs.id == rhs.id
            && lhs.previousFailure == rhs.previousFailure
    }
}
