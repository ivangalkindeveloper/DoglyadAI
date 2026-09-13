import Foundation

public final class DTextFieldRegexReplacingFormatter: DTextFieldFormatter {
    private let regularExpression: NSRegularExpression
    private let replacementTemplate: String

    public init(
        pattern: String,
        options: NSRegularExpression.Options = [],
        replacementTemplate: String = ""
    ) {
        do {
            regularExpression = try NSRegularExpression(
                pattern: pattern,
                options: options
            )
        } catch {
            preconditionFailure("Invalid regular expression: \(pattern)")
        }
        self.replacementTemplate = replacementTemplate
    }

    public func format(
        currentValue _: String,
        proposedValue: String
    ) -> String {
        regularExpression.stringByReplacingMatches(
            in: proposedValue,
            range: NSRange(proposedValue.startIndex..., in: proposedValue),
            withTemplate: replacementTemplate
        )
    }
}
