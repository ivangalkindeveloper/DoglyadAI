@frozen public enum DNeuralUltrasoundVoiceFieldId: String, Codable, CaseIterable, Hashable, Sendable {
    case examinationNumber
    case patientName
    case patientGender
    case patientDateOfBirth
    case patientHeightCM
    case patientWeightKG
    case patientComplaints
    case examinationDescription

    var isPatientDateOfBirth: Bool {
        switch self {
        case .patientDateOfBirth: true
        case .examinationNumber, .patientName, .patientGender, .patientHeightCM, .patientWeightKG, .patientComplaints, .examinationDescription: false
        }
    }

    var isPatientComplaints: Bool {
        switch self {
        case .patientComplaints: true
        case .examinationNumber, .patientName, .patientGender, .patientDateOfBirth, .patientHeightCM, .patientWeightKG, .examinationDescription: false
        }
    }

    var isExaminationDescription: Bool {
        switch self {
        case .examinationDescription: true
        case .examinationNumber, .patientName, .patientGender, .patientDateOfBirth, .patientHeightCM, .patientWeightKG, .patientComplaints: false
        }
    }

    var isExaminationNumber: Bool {
        switch self {
        case .examinationNumber: true
        case .patientName, .patientGender, .patientDateOfBirth, .patientHeightCM, .patientWeightKG, .patientComplaints, .examinationDescription: false
        }
    }

    public var wireValue: String {
        switch self {
        case .examinationNumber: "examination_number"
        case .patientName: "patient_name"
        case .patientGender: "patient_gender"
        case .patientDateOfBirth: "patient_date_of_birth"
        case .patientHeightCM: "patient_height_cm"
        case .patientWeightKG: "patient_weight_kg"
        case .patientComplaints: "patient_complaints"
        case .examinationDescription: "examination_description"
        }
    }

    public init?(
        wireValue: String,
    ) {
        guard let field = Self.allCases.first(
            where: { $0.wireValue == wireValue },
        ) else { return nil }
        self = field
    }
}
