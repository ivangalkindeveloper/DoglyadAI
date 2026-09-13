public final class DTextFieldIntRangeValidator: DTextFieldValidator {
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
        guard let number = Int(value), validRange.contains(number) else {
            return invalidValueErrorText
        }
        return nil
    }
}
