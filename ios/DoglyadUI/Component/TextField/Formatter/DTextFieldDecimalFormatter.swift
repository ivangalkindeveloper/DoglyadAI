public final class DTextFieldDecimalFormatter: DTextFieldFormatter {
    private static let digits = Set("0123456789")
    private static let decimalSeparators = Set(".,")

    private let allowsNegative: Bool
    private let maxFractionLength: Int?

    public init(
        allowsNegative: Bool = false,
        maxFractionLength: Int? = nil
    ) {
        if let maxFractionLength {
            precondition(maxFractionLength >= 0)
        }
        self.allowsNegative = allowsNegative
        self.maxFractionLength = maxFractionLength
    }

    public func format(
        currentValue _: String,
        proposedValue: String
    ) -> String {
        var result = ""
        var hasDecimalSeparator = false
        var fractionLength = 0

        for character in proposedValue {
            if Self.digits.contains(character) {
                if let maxFractionLength,
                   hasDecimalSeparator,
                   fractionLength >= maxFractionLength
                {
                    continue
                }
                result.append(character)
                if hasDecimalSeparator {
                    fractionLength += 1
                }
            } else if Self.decimalSeparators.contains(character),
                      !hasDecimalSeparator,
                      maxFractionLength != 0
            {
                if result.isEmpty || result == "-" {
                    result.append("0")
                }
                result.append(".")
                hasDecimalSeparator = true
            } else if character == "-", allowsNegative, result.isEmpty {
                result.append(character)
            }
        }

        return result
    }
}
