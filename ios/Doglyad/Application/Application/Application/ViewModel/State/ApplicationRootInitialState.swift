@MainActor
final class ApplicationRootInitialState: ApplicationRootStateProtocol, @MainActor Equatable {
    let id = ApplicationRootViewType.splash

    init() {}

    static func == (
        lhs: ApplicationRootInitialState,
        rhs: ApplicationRootInitialState,
    ) -> Bool {
        lhs.id == rhs.id
    }
}
