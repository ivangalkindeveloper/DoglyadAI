import Foundation

public protocol DDatabaseSettingsAIProtocol: AnyObject {
    func getSettingsAIData() throws -> Data?

    func setSettingsAIData(
        _ value: Data,
    )
}
