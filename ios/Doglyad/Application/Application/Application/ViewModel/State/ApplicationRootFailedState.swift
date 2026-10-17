@MainActor
final class ApplicationRootFailedState: ApplicationRootStateProtocol {
    let id = ApplicationRootViewType.error
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }
}
