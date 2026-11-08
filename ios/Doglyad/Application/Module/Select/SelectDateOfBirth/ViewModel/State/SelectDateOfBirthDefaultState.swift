@MainActor
final class SelectDateOfBirthDefaultState: SelectDateOfBirthStateProtocol, @MainActor Equatable {
    static func == (
        _: SelectDateOfBirthDefaultState,
        _: SelectDateOfBirthDefaultState,
    ) -> Bool {
        true
    }
}
