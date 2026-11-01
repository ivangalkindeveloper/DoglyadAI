import Foundation

extension Int {
    /// Formats a price stored in hundredths of its currency, such as kopecks or cents.
    func formattedCurrencyFromMinorUnits(
        code: String,
        locale: Locale = .autoupdatingCurrent,
    ) -> String {
        (Decimal(
            self,
        ) / 100).formatted(
            Decimal.FormatStyle.Currency(
                code: code,
                locale: locale,
            ),
        )
    }
}
