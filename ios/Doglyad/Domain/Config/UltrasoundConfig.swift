import Foundation

struct UltrasoundConfig: Codable {
    let neuralModel: UltrasoundNeuralModelConfig
    let examinationNeuralModel: UltrasoundExaminationNeuralModelConfig
    let scanPhotoMaxNumber: Int
    let scanPhotoResizeMaxDimension: Double
    let scanPhotoCompressionQuality: Double
    let defaultPatientDateOfBirthGap: Int
}

extension UltrasoundConfig {
    static let `default` = UltrasoundConfig(
        neuralModel: .default,
        examinationNeuralModel: .default,
        scanPhotoMaxNumber: 0,
        scanPhotoResizeMaxDimension: 0,
        scanPhotoCompressionQuality: 0,
        defaultPatientDateOfBirthGap: 0,
    )
}
