@frozen public enum VoiceFieldId: String, Codable, CaseIterable, Hashable, Sendable {
    case examinationNumber
    case patientName
    case patientGender
    case patientDateOfBirth
    case patientHeightCM
    case patientWeightKG
    case patientComplaints
    case examinationDescription
}
