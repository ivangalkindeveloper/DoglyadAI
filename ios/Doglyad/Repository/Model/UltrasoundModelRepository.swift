import DoglyadDatabase
import Foundation

final class UltrasoundModelRepository: UltrasoundModelRepositoryProtocol {
    let database: DDatabaseProtocol

    init(
        database: DDatabaseProtocol,
    ) {
        self.database = database
    }
}

// MARK: Model -

extension UltrasoundModelRepository {
    func getSelectedModelId() -> String? {
        database.getSelectedUSExaminationNeuralModelId()
    }

    func setSelectedModelId(
        id: String,
    ) {
        database.setSelectedUSExaminationNeuralModelId(
            value: id,
        )
    }

    func getIsMarkdown() -> Bool {
        database.getNeuralModelIsMarkdown()
    }

    func setIsMarkdown(
        _ value: Bool,
    ) {
        database.setNeuralModelIsMarkdown(
            value: value,
        )
    }

    func getTemperature() -> Double? {
        database.getNeuralModelTemperature()
    }

    func setTemperature(
        _ value: Double?,
    ) {
        database.setNeuralModelTemperature(
            value: value,
        )
    }

    func getMaxTokens() -> Int? {
        database.getNeuralModelMaxTokens()
    }

    func setMaxTokens(
        _ value: Int?,
    ) {
        database.setNeuralModelMaxTokens(
            value: value,
        )
    }
}
