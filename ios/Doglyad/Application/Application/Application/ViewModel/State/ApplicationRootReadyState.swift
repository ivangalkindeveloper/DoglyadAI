@MainActor
final class ApplicationRootReadyState: ApplicationRootStateProtocol, @MainActor Equatable {
    let id = ApplicationRootViewType.main
    let container: DependencyContainer

    init(
        container: DependencyContainer,
    ) {
        self.container = container
    }

    static func == (
        lhs: ApplicationRootReadyState,
        rhs: ApplicationRootReadyState,
    ) -> Bool {
        lhs.id == rhs.id
            && lhs.container === rhs.container
    }
}
