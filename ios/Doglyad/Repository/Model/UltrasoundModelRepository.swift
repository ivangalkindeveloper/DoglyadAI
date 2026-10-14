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
    func getSelectedModelId() async throws -> String? {
        database.getSelectedUSExaminationNeuralModelId()
    }

    func setSelectedModelId(
        id: String,
    ) async throws {
        database.setSelectedUSExaminationNeuralModelId(
            value: id,
        )
    }

    func getIsMarkdown() async throws -> Bool {
        database.getNeuralModelIsMarkdown()
    }

    func setIsMarkdown(
        _ isMarkdown: Bool,
    ) async throws {
        database.setNeuralModelIsMarkdown(
            isMarkdown: isMarkdown,
        )
    }

    func getTemperature() async throws -> Double? {
        database.getNeuralModelTemperature()
    }

    func setTemperature(
        _ value: Double?,
    ) async throws {
        database.setNeuralModelTemperature(
            value: value,
        )
    }

    func getMaxTokens() async throws -> Int? {
        database.getNeuralModelMaxTokens()
    }

    func setMaxTokens(
        _ value: Int?,
    ) async throws {
        database.setNeuralModelMaxTokens(
            value: value,
        )
    }
}
