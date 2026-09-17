import DoglyadNeuralModel

enum PatientGender: String, Codable, Sendable {
    case male
    case female

    static func fromUSExaminationNeuralModelResponse(
        _ response: DExaminationNeuralModelResponse.Gender?
    ) -> Self? {
        switch response {
        case .male:
            return .male
        case .female:
            return .female
        case nil:
            return nil
        case .some:
            return nil
        }
    }
}
