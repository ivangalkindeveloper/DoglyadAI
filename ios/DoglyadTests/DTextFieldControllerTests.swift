@testable import DoglyadUI
import Testing

struct DTextFieldControllerTests {
    @Test
    func returnsNilForEmptyText() {
        let controller = DTextFieldController()

        #expect(controller.value == nil)
    }

    @Test
    func returnsCurrentNonEmptyText() {
        let controller = DTextFieldController(initialText: "Value")

        #expect(controller.value == "Value")
    }

    @Test
    func appliesFormattersToInitialAndUpdatedText() {
        let controller = DTextFieldController(
            initialText: "12a",
            formatters: [DTextFieldIntegerFormatter()]
        )

        #expect(controller.text == "12")

        controller.setText("34b")

        #expect(controller.text == "34")
    }

    @Test
    func revalidatesTextAfterFirstValidationAttempt() {
        let controller = DTextFieldController(isRequired: true)

        #expect(!controller.validate())
        #expect(controller.isError)
        #expect(controller.errorText == nil)

        controller.setText("Value")

        #expect(!controller.isError)
        #expect(controller.errorText == nil)

        controller.setText("")

        #expect(controller.isError)
        #expect(controller.errorText == nil)
    }

    @Test
    func clearResetsTextAndValidationState() {
        let controller = DTextFieldController(isRequired: true)
        controller.validate()

        controller.clear()

        #expect(controller.value == nil)
        #expect(!controller.isError)
        #expect(controller.errorText == nil)
    }
}
