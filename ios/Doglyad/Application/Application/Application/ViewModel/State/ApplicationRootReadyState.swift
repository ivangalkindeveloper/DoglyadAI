@MainActor
final class ApplicationRootReadyState: ApplicationRootStateProtocol {
    let id = ApplicationRootViewType.main
    let container: DependencyContainer

    init(
        container: DependencyContainer,
    ) {
        self.container = container
    }
}
