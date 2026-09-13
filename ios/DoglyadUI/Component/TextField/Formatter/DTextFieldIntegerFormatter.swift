public final class DTextFieldIntegerFormatter: DTextFieldFormatter {
    private static let digits = Set("0123456789")

    private let allowsNegative: Bool

    public init(
        allowsNegative: Bool = false
    ) {
        self.allowsNegative = allowsNegative
    }

    public func format(
        currentValue _: String,
        proposedValue: String
    ) -> String {
        var result = ""
        for character in proposedValue {
            if Self.digits.contains(character) {
                result.append(character)
            } else if character == "-", allowsNegative, result.isEmpty {
                result.append(character)
            }
        }
        return result
    }
}
