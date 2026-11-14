@MainActor
final class ImportMediaDefaultState: ImportMediaStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: ImportMediaDefaultState,
        _: ImportMediaDefaultState,
    ) -> Bool {
        true
    }
}
