@MainActor
final class ImportMediaDefaultState: ImportMediaStateProtocol, @MainActor Equatable {
    static func == (
        _: ImportMediaDefaultState,
        _: ImportMediaDefaultState,
    ) -> Bool {
        true
    }
}
