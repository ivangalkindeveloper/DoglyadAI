@MainActor
final class ApplicationRootSuccessState: ApplicationRootStateProtocol, @MainActor Equatable {
    let id = ApplicationRootViewType.main
    let container: DependencyContainer

    init(
        container: DependencyContainer,
    ) {
        self.container = container
    }

    static func == (
        lhs: ApplicationRootSuccessState,
        rhs: ApplicationRootSuccessState,
    ) -> Bool {
        lhs.id == rhs.id
            && lhs.container === rhs.container
    }
}
