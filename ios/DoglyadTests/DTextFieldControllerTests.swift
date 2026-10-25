@testable import DoglyadUI
import Testing

struct DTextFieldControllerTests {
    @Test
    func returnsNilForEmptyText() {
        let inputTextController = DTextFieldController()

        #expect(
            inputTextController.value == nil,
        )
    }

    @Test
    func returnsCurrentNonEmptyText() {
        let inputTextController = DTextFieldController(
            initialText: "Value",
        )

        #expect(
            inputTextController.value == "Value",
        )
    }

    @Test
    func appliesFormattersToInitialAndUpdatedText() {
        let inputTextController = DTextFieldController(
            initialText: "12a",
            formatters: [DTextFieldIntegerFormatter()],
        )

        #expect(
            inputTextController.text == "12",
        )

        inputTextController.setText(
            "34b",
        )

        #expect(
            inputTextController.text == "34",
        )
    }

    @Test
    func revalidatesTextAfterFirstValidationAttempt() {
        let inputTextController = DTextFieldController(
            isRequired: true,
        )

        #expect(
            !inputTextController.validate(),
        )
        #expect(
            inputTextController.isError,
        )
        #expect(
            inputTextController.errorText == nil,
        )

        inputTextController.setText(
            "Value",
        )

        #expect(
            !inputTextController.isError,
        )
        #expect(
            inputTextController.errorText == nil,
        )

        inputTextController.setText(
            "",
        )

        #expect(
            inputTextController.isError,
        )
        #expect(
            inputTextController.errorText == nil,
        )
    }

    @Test
    func clearResetsTextAndValidationState() {
        let inputTextController = DTextFieldController(
            isRequired: true,
        )
        inputTextController.validate()

        inputTextController.clear()

        #expect(
            inputTextController.value == nil,
        )
        #expect(
            !inputTextController.isError,
        )
        #expect(
            inputTextController.errorText == nil,
        )
    }

    @Test
    func restoredTextIsRetainedAndValidatedBeforeEditing() {
        let inputTextController = DTextFieldController(
            formatters: [DTextFieldMaxLengthFormatter(
                maxLength: 3,
            )],
            validators: [DTextFieldLengthValidator(
                validRange: 0 ... 3,
                invalidValueErrorText: "Too long",
            )],
        )
        inputTextController.restoreText(
            "Original text",
        )

        #expect(
            inputTextController.text == "Original text",
        )
        #expect(
            inputTextController.isError,
        )
        #expect(
            inputTextController.errorText == "Too long",
        )

        inputTextController.setText(
            "1234",
        )

        #expect(
            inputTextController.text == "123",
        )
        #expect(
            !inputTextController.isError,
        )
    }

    @Test
    func maxLengthFormatterFollowsOtherFormattersAndRetainsWholeCharacters() {
        let inputTextController = DTextFieldController(
            formatters: [
                DTextFieldRegexReplacingFormatter(
                    pattern: #"\s+"#,
                ),
                DTextFieldMaxLengthFormatter(
                    maxLength: 2,
                ),
            ],
        )
        inputTextController.setText(
            " 👨‍👩‍👧‍👦 е\u{301} x",
        )
        #expect(
            inputTextController.text == "👨‍👩‍👧‍👦е\u{301}",
        )
    }
}
