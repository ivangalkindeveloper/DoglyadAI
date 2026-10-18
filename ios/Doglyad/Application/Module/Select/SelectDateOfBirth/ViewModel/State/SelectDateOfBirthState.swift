@MainActor
final class SelectDateOfBirthState: SelectDateOfBirthStateProtocol, @MainActor Equatable {
    static func == (
        _: SelectDateOfBirthState,
        _: SelectDateOfBirthState,
    ) -> Bool {
        true
    }
}
