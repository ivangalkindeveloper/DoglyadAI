import Foundation

public final class DTextFieldEmailValidator: DTextFieldValidatorProtocol {
    private let regexValidator: DTextFieldRegexValidator

    public init(
        invalidValueErrorText: String,
    ) {
        regexValidator = DTextFieldRegexValidator(
            pattern: #"^[A-Z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[A-Z0-9!#$%&'*+/=?^_`{|}~-]+)*@[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?(?:\.[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?)+$"#,
            options: [.caseInsensitive],
            invalidValueErrorText: invalidValueErrorText,
        )
    }

    public func errorText(
        for value: String?,
    ) -> String? {
        regexValidator.errorText(
            for: value,
        )
    }
}
