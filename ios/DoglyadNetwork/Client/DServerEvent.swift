public import Foundation

public struct DServerEvent: Sendable {
    public let id: String?
    public let event: String
    public let data: Data

    init(
        id: String?,
        event: String,
        data: Data,
    ) {
        self.id = id
        self.event = event
        self.data = data
    }
}
