public struct DTextFieldFocusValidationItem<Focus: Hashable> {
    public let focus: Focus
    public let controller: DTextFieldController

    public init(
        focus: Focus,
        controller: DTextFieldController
    ) {
        self.focus = focus
        self.controller = controller
    }
}
