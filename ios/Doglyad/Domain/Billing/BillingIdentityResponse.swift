import Foundation

struct BillingIdentityResponse: Codable {
    let ownerId: UUID
    let accessToken: String
}
