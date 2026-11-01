import Foundation

struct BillingPrice: Decodable, Equatable, Sendable {
    let amountMinor: Int
    let currencyIso2Code: String
}
