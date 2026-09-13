enum InitializationError: Error {
    case noInternetConnection
    case serviceUnavailable(email: String)
    case usExaminationTypesEmpty
    case usExaminationNeuralModelsEmpty
    case examinationNeuralModelPromptEmpty
    case common
}
