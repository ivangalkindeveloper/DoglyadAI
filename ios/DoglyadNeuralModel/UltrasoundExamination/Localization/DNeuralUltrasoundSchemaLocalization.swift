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

    init(
        patientName: String,
        patientGender: String,
        patientDateOfBirth: String,
        patientHeightCM: String,
        patientWeightKG: String,
        patientComplaints: String,
        examinationDescription: String,
        fieldId: String,
        value: String,
        evidence: String,
        accuracy: String,
    ) {
        self.patientName = patientName
        self.patientGender = patientGender
        self.patientDateOfBirth = patientDateOfBirth
        self.patientHeightCM = patientHeightCM
        self.patientWeightKG = patientWeightKG
        self.patientComplaints = patientComplaints
        self.examinationDescription = examinationDescription
        self.fieldId = fieldId
        self.value = value
        self.evidence = evidence
        self.accuracy = accuracy
    }
}
