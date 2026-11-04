public import Foundation

public struct DServerEvent: Sendable {
    public let id: String?
    public let event: String
    public let data: Data
}
