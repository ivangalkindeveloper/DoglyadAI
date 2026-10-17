public final class DTextFieldDecimalFormatter: DTextFieldFormatterProtocol {
    private static let digits = Set(
        "0123456789",
    )
    private static let decimalSeparators = Set(
        ".,",
    )

    private let isNegativeAllowed: Bool
    private let maxFractionLength: Int?

    public init(
        isNegativeAllowed: Bool = false,
        maxFractionLength: Int? = nil,
    ) {
        if let maxFractionLength {
            precondition(
                maxFractionLength >= 0,
            )
        }
        self.isNegativeAllowed = isNegativeAllowed
        self.maxFractionLength = maxFractionLength
    }

    public func format(
        currentValue _: String,
        proposedValue: String,
    ) -> String {
        var result = ""
        var isDecimalSeparatorPresent = false
        var fractionLength = 0

        for character in proposedValue {
            if Self.digits.contains(
                character,
            ) {
                if let maxFractionLength,
                   isDecimalSeparatorPresent,
                   fractionLength >= maxFractionLength
                {
                    continue
                }
                result.append(
                    character,
                )
                if isDecimalSeparatorPresent {
                    fractionLength += 1
                }
            } else if Self.decimalSeparators.contains(
                character,
            ),
                !isDecimalSeparatorPresent,
                maxFractionLength != 0
            {
                if result.isEmpty || result == "-" {
                    result.append(
                        "0",
                    )
                }
                result.append(
                    ".",
                )
                isDecimalSeparatorPresent = true
            } else if character == "-", isNegativeAllowed, result.isEmpty {
                result.append(
                    character,
                )
            }
        }

        return result
    }
}
