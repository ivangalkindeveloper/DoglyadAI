@MainActor
final class ImportMediaState: ImportMediaStateProtocol, @MainActor Equatable {
    static func == (
        _: ImportMediaState,
        _: ImportMediaState,
    ) -> Bool {
        true
    }
}
