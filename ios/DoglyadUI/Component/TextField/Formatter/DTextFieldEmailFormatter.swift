public final class DTextFieldEmailFormatter: DTextFieldFormatter {
    private static let localPartCharacters = Set(
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.!#$%&'*+-/=?^_`{|}~"
    )
    private static let domainCharacters = Set(
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-"
    )

    public init() {}

    public func format(
        currentValue _: String,
        proposedValue: String
    ) -> String {
        var result = ""
        var hasAtSign = false

        for character in proposedValue {
            if character == "@", !hasAtSign {
                result.append(character)
                hasAtSign = true
            } else if hasAtSign {
                if Self.domainCharacters.contains(character) {
                    result.append(character)
                }
            } else if Self.localPartCharacters.contains(character) {
                result.append(character)
            }
        }

        return result
    }
}
