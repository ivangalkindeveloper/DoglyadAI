public struct DTextFieldFocusValidationItem<Focus: Hashable> {
    public let focus: Focus
    public let inputTextController: DTextFieldController

    public init(
        focus: Focus,
        inputTextController: DTextFieldController,
    ) {
        self.focus = focus
        self.inputTextController = inputTextController
    }
}
