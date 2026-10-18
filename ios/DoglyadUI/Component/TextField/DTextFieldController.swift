import Combine

public final class DTextFieldController: ObservableObject {
    @Published public private(set) var text: String
    @Published private(set) var isError: Bool = false
    @Published private(set) var errorText: String?

    private let isRequired: Bool
    private let formatters: [any DTextFieldFormatterProtocol]
    private let validators: [any DTextFieldValidatorProtocol]
    private var isValidationAttempted = false

    public init(
        initialText: String = "",
        isRequired: Bool = false,
        formatters: [any DTextFieldFormatterProtocol] = [],
        validators: [any DTextFieldValidatorProtocol] = [],
    ) {
        self.isRequired = isRequired
        self.formatters = formatters
        self.validators = validators

        var formattedText = initialText
        for formatter in formatters {
            formattedText = formatter.format(
                currentValue: "",
                proposedValue: formattedText,
            )
        }
        text = formattedText
    }

    public var value: String? {
        text.isEmpty ? nil : text
    }

    public func setText(
        _ proposedValue: String,
    ) {
        var formattedText = proposedValue
        for formatter in formatters {
            formattedText = formatter.format(
                currentValue: text,
                proposedValue: formattedText,
            )
        }
        guard formattedText != text else { return }

        text = formattedText
        if isValidationAttempted {
            updateValidationState()
        } else {
            clearError()
        }
    }

    @discardableResult
    public func validate() -> Bool {
        isValidationAttempted = true
        return updateValidationState()
    }

    public func showError(
        text: String,
    ) {
        isError = true
        errorText = text
    }

    public func clear() {
        isValidationAttempted = false
        text = ""
        clearError()
    }

    @discardableResult
    private func updateValidationState() -> Bool {
        if isRequired, value == nil {
            isError = true
            errorText = nil
            return false
        }

        for validator in validators {
            if let errorText = validator.errorText(
                for: value,
            ) {
                isError = true
                self.errorText = errorText
                return false
            }
        }

        clearError()
        return true
    }

    private func clearError() {
        isError = false
        errorText = nil
    }
}
