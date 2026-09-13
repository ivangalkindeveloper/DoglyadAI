public final class DTextFieldLengthValidator: DTextFieldValidator {
    private let validRange: ClosedRange<Int>
    private let invalidValueErrorText: String

    public init(
        validRange: ClosedRange<Int>,
        invalidValueErrorText: String
    ) {
        self.validRange = validRange
        self.invalidValueErrorText = invalidValueErrorText
    }

    public func errorText(
        for value: String?
    ) -> String? {
        guard let value else { return nil }
        return validRange.contains(value.count) ? nil : invalidValueErrorText
    }
}
