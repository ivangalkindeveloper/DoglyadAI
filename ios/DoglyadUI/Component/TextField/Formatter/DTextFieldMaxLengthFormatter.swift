public final class DTextFieldMaxLengthFormatter: DTextFieldFormatterProtocol {
    private let maxLength: Int

    public init(
        maxLength: Int,
    ) {
        precondition(
            maxLength >= 0,
        )
        self.maxLength = maxLength
    }

    public func format(
        currentValue _: String,
        proposedValue: String,
    ) -> String {
        String(
            proposedValue.prefix(
                maxLength,
            ),
        )
    }
}
