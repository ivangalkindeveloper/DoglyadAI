import Foundation

struct BillingPrice: Codable, Equatable, Sendable {
    let amountMinor: Int
    let currencyIso2Code: String

    init(
        amountMinor: Int,
        currencyIso2Code: String,
    ) {
        self.amountMinor = amountMinor
        self.currencyIso2Code = currencyIso2Code
    }
}
