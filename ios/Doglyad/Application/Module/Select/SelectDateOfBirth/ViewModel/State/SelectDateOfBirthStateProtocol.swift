import Foundation

@MainActor
protocol SelectDateOfBirthStateProtocol: AnyObject {
    var date: Date {
        get
    }

    func copyWith(
        date: Date?,
    ) -> SelectDateOfBirthDefaultState
}
