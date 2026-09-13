import DoglyadUI
import Testing

struct DTextFieldFormatterTests {
    @Test
    func regexFormatterReplacesMatchingText() {
        let formatter = DTextFieldRegexReplacingFormatter(
            pattern: #"\s+"#
        )

        let value = formatter.format(
            currentValue: "",
            proposedValue: "one two\nthree"
        )

        #expect(value == "onetwothree")
    }

    @Test
    func maxLengthFormatterLimitsCharacters() {
        let formatter = DTextFieldMaxLengthFormatter(maxLength: 3)

        let value = formatter.format(
            currentValue: "",
            proposedValue: "1234"
        )

        #expect(value == "123")
    }

    @Test
    func integerFormatterRemovesNonNumericCharacters() {
        let formatter = DTextFieldIntegerFormatter()

        let value = formatter.format(
            currentValue: "",
            proposedValue: "1a2.3"
        )

        #expect(value == "123")
    }

    @Test
    func decimalFormatterNormalizesSeparatorAndLimitsFraction() {
        let formatter = DTextFieldDecimalFormatter(
            maxFractionLength: 2
        )

        let value = formatter.format(
            currentValue: "",
            proposedValue: "12,34.5a"
        )

        #expect(value == "12.34")
    }

    @Test
    func emailFormatterRemovesUnsupportedCharactersAndExtraAtSign() {
        let formatter = DTextFieldEmailFormatter()

        let value = formatter.format(
            currentValue: "",
            proposedValue: " doctor+tag@example.com\n@"
        )

        #expect(value == "doctor+tag@example.com")
    }
}
