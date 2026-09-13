import DoglyadUI
import Testing

struct DTextFieldValidatorTests {
    @Test
    func regexValidatorRequiresFullMatch() {
        let validator = DTextFieldRegexValidator(
            pattern: #"^[0-9]+$"#,
            invalidValueErrorText: "Invalid"
        )

        #expect(validator.errorText(for: nil) == nil)
        #expect(validator.errorText(for: "123") == nil)
        #expect(validator.errorText(for: "123a") == "Invalid")
    }

    @Test
    func emailValidatorAcceptsOnlyCompleteEmail() {
        let validator = DTextFieldEmailValidator(
            invalidValueErrorText: "Invalid email"
        )

        #expect(validator.errorText(for: nil) == nil)
        #expect(validator.errorText(for: "doctor@example.com") == nil)
        #expect(validator.errorText(for: "doctor@") == "Invalid email")
        #expect(validator.errorText(for: "doctor..name@example.com") == "Invalid email")
    }

    @Test
    func numberValidatorsCheckParsingAndRange() {
        let doubleValidator = DTextFieldDoubleRangeValidator(
            validRange: 1 ... 250,
            invalidValueErrorText: "Invalid double"
        )
        let intValidator = DTextFieldIntRangeValidator(
            validRange: 1 ... 10,
            invalidValueErrorText: "Invalid integer"
        )

        #expect(doubleValidator.errorText(for: "180.5") == nil)
        #expect(doubleValidator.errorText(for: "0") == "Invalid double")
        #expect(intValidator.errorText(for: "5") == nil)
        #expect(intValidator.errorText(for: "11") == "Invalid integer")
    }

    @Test
    func lengthValidatorChecksCharacterCount() {
        let validator = DTextFieldLengthValidator(
            validRange: 2 ... 4,
            invalidValueErrorText: "Invalid length"
        )

        #expect(validator.errorText(for: "abc") == nil)
        #expect(validator.errorText(for: "a") == "Invalid length")
    }
}
