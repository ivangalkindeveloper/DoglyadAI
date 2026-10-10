import Foundation

public struct RequestLimitDB: Codable, Sendable, Equatable {
    public let count: Int
    public let date: Date

    public init(
        count: Int,
        date: Date,
    ) {
        self.count = count
        self.date = date
    }
}
