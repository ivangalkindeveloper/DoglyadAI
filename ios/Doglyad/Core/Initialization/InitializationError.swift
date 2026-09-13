import Foundation

enum InitializationError: Error {
    case noInternetConnection
    case serviceUnavailable(email: String)
    case newVersion(appleUpdateUrl: URL, appStoreId: String)
    case usExaminationTypesEmpty
    case usExaminationNeuralModelsEmpty
    case examinationNeuralModelPromptEmpty
    case common
}
