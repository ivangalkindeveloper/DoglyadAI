public protocol DTextFieldValidator {
    func errorText(
        for value: String?
    ) -> String?
}
