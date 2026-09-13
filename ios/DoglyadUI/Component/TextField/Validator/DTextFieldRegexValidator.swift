import Foundation

public final class DTextFieldRegexValidator: DTextFieldValidator {
    private let regularExpression: NSRegularExpression
    private let invalidValueErrorText: String

    public init(
        pattern: String,
        options: NSRegularExpression.Options = [],
        invalidValueErrorText: String
    ) {
        do {
            regularExpression = try NSRegularExpression(
                pattern: pattern,
                options: options
            )
        } catch {
            preconditionFailure("Invalid regular expression: \(pattern)")
        }
        self.invalidValueErrorText = invalidValueErrorText
    }

    public func errorText(
        for value: String?
    ) -> String? {
        guard let value else { return nil }

        let range = NSRange(value.startIndex..., in: value)
        let match = regularExpression.firstMatch(
            in: value,
            range: range
        )
        return match?.range == range ? nil : invalidValueErrorText
    }
}
