@MainActor
public protocol DTextFieldFocusValidating {
    associatedtype Focus: Hashable

    var focusList: [DTextFieldFocusValidationItem<Focus>] { get }

    func firstInvalidFocus() -> Focus?
}

public extension DTextFieldFocusValidating {
    func firstInvalidFocus() -> Focus? {
        var firstInvalidFocus: Focus?

        for item in focusList {
            if !item.controller.validate(), firstInvalidFocus == nil {
                firstInvalidFocus = item.focus
            }
        }

        return firstInvalidFocus
    }
}
