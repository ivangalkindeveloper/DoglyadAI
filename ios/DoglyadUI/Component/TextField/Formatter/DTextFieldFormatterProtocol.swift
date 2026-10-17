public protocol DTextFieldFormatterProtocol {
    func format(
        currentValue: String,
        proposedValue: String,
    ) -> String
}
