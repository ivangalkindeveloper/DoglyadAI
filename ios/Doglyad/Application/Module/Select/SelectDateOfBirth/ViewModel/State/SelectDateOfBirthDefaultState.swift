import Foundation

@MainActor
final class SelectDateOfBirthDefaultState: SelectDateOfBirthStateProtocol, @MainActor Equatable {
    let date: Date

    init(
        date: Date = Date(),
    ) {
        self.date = date
    }

    func copyWith(
        date: Date? = nil,
    ) -> SelectDateOfBirthDefaultState {
        SelectDateOfBirthDefaultState(
            date: date ?? self.date,
        )
    }

    static func == (
        lhs: SelectDateOfBirthDefaultState,
        rhs: SelectDateOfBirthDefaultState,
    ) -> Bool {
        lhs.date == rhs.date
    }
}
