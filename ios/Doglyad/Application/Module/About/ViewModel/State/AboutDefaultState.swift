@MainActor
final class AboutDefaultState: AboutStateProtocol, @MainActor Equatable {
    static func == (
        _: AboutDefaultState,
        _: AboutDefaultState,
    ) -> Bool {
        true
    }
}
