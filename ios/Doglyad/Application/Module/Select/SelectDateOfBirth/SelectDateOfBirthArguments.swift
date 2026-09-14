import Foundation
import Router

final class SelectDateOfBirthArguments: RouteArgumentsProtocol {
    let currentValue: Date?
    let onSelected: (Date) -> Void

    init(
        currentValue: Date? = nil,
        onSelected: @escaping (Date) -> Void
    ) {
        self.currentValue = currentValue
        self.onSelected = onSelected
    }
}
