import Foundation

public protocol DDatabaseNeuralModelSettingsProtocol: AnyObject {
    func getNeuralModelIsMarkdown() -> Bool

    func setNeuralModelIsMarkdown(
        value: Bool,
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

extension DDatabase: DDatabaseNeuralModelSettingsProtocol {
    public func getNeuralModelIsMarkdown() -> Bool {
        getBool(
            .neuralModelIsMarkdown,
        )
    }

    public func setNeuralModelIsMarkdown(
        value: Bool,
    ) {
        setValue(
            value,
            .neuralModelIsMarkdown,
        )
    }

    public func getNeuralModelTemperature() -> Double? {
        getDouble(
            .neuralModelTemperature,
        )
    }

    public func setNeuralModelTemperature(
        value: Double?,
    ) {
        if let value {
            setValue(
                value,
                .neuralModelTemperature,
            )
        } else {
            removeValue(
                .neuralModelTemperature,
            )
        }
    }

    public func getNeuralModelMaxTokens() -> Int? {
        getInt(
            .neuralModelMaxTokens,
        )
    }

    public func setNeuralModelMaxTokens(
        value: Int?,
    ) {
        if let value {
            setValue(
                value,
                .neuralModelMaxTokens,
            )
        } else {
            removeValue(
                .neuralModelMaxTokens,
            )
        }
    }
}
