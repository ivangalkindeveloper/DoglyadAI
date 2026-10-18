@MainActor
final class AboutState: AboutStateProtocol, @MainActor Equatable {
    static func == (
        _: AboutState,
        _: AboutState,
    ) -> Bool {
        true
    }
}
