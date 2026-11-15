import Foundation

struct BillingPrice: Codable, Equatable, Sendable {
    let amountMinor: Int
    let oldAmountMinor: Int
    let currencyIso2Code: String

    init(
        amountMinor: Int,
        oldAmountMinor: Int,
        currencyIso2Code: String,
    ) {
        self.amountMinor = amountMinor
        self.oldAmountMinor = oldAmountMinor
        self.currencyIso2Code = currencyIso2Code
    }
}
