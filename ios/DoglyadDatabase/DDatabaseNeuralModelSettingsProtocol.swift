import Foundation

public protocol DDatabaseNeuralModelSettingsProtocol: AnyObject {
    func getNeuralModelIsMarkdown() -> Bool

    func setNeuralModelIsMarkdown(
        isMarkdown: Bool,
    )

    func getNeuralModelTemperature() -> Double?

    func setNeuralModelTemperature(
        value: Double?,
    )

    func getNeuralModelMaxTokens() -> Int?

    func setNeuralModelMaxTokens(
        value: Int?,
    )
}
