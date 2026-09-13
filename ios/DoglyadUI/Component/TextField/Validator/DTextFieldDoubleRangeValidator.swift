public final class DTextFieldDoubleRangeValidator: DTextFieldValidator {
    private let validRange: ClosedRange<Double>
    private let invalidValueErrorText: String

    public init(
        validRange: ClosedRange<Double>,
        invalidValueErrorText: String
    ) {
        self.validRange = validRange
        self.invalidValueErrorText = invalidValueErrorText
    }

    public func errorText(
        for value: String?
    ) -> String? {
        guard let value else { return nil }
        guard let number = Double(value), validRange.contains(number) else {
            return invalidValueErrorText
        }
        return nil
    }
}
