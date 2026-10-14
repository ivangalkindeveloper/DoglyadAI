public final class DTextFieldIntegerFormatter: DTextFieldFormatter {
    private static let digits = Set(
        "0123456789",
    )

    private let isNegativeAllowed: Bool

    public init(
        isNegativeAllowed: Bool = false,
    ) {
        self.isNegativeAllowed = isNegativeAllowed
    }

    public func format(
        currentValue _: String,
        proposedValue: String,
    ) -> String {
        var result = ""
        for character in proposedValue {
            if Self.digits.contains(
                character,
            ) {
                result.append(
                    character,
                )
            } else if character == "-", isNegativeAllowed, result.isEmpty {
                result.append(
                    character,
                )
            }
        }
        return result
    }
}
