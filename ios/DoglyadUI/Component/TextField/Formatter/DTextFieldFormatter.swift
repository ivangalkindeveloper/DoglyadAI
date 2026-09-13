public protocol DTextFieldFormatter {
    func format(
        currentValue: String,
        proposedValue: String
    ) -> String
}
