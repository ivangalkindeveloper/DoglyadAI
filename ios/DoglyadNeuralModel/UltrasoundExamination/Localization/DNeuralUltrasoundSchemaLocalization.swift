/// Localized descriptions used when constructing Foundation Models schemas.
public struct DNeuralUltrasoundSchemaLocalization: Decodable, Sendable {
    public let patientName: String
    public let patientGender: String
    public let patientDateOfBirth: String
    public let patientHeightCM: String
    public let patientWeightKG: String
    public let patientComplaints: String
    public let examinationDescription: String
    public let fieldId: String
    public let value: String
    public let evidence: String
    public let accuracy: String
}
