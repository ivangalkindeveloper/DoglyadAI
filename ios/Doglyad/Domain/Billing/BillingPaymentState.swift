import Foundation

enum BillingPaymentState: String, Decodable, Sendable {
    case created
    case pending
    case succeeded
    case canceled
    case refunded
    case needsReview
}
