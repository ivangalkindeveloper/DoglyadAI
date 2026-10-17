@MainActor
final class ApplicationRootInitializingState: ApplicationRootStateProtocol {
    let id: ApplicationRootViewType
    let previousFailure: ApplicationRootFailedState?

    init(
        previousFailure: ApplicationRootFailedState? = nil,
    ) {
        self.previousFailure = previousFailure
        id = previousFailure?.id ?? .splash
    }
}
