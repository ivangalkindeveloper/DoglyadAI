@MainActor
final class SelectDateOfBirthDefaultState: SelectDateOfBirthStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: SelectDateOfBirthDefaultState,
        _: SelectDateOfBirthDefaultState,
    ) -> Bool {
        true
    }
}
