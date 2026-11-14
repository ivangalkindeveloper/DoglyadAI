@MainActor
final class AboutDefaultState: AboutStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: AboutDefaultState,
        _: AboutDefaultState,
    ) -> Bool {
        true
    }
}
