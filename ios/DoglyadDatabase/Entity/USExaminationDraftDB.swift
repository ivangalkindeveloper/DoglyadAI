import Foundation
import SwiftData

@Model
public final class USExaminationDraftDB {
    public var examinationNumber: String
    public var patientName: String
    public var patientGenderRawValue: String
    public var patientDateOfBirth: Date
    public var patientHeightCM: String
    public var patientWeightKG: String
    public var patientComplaints: String
    public var examinationDescription: String
    public var isPatientPreparedForExamination: Bool = true
    @Relationship(
        deleteRule: .cascade,
    ) public var photos: [USExaminationDraftPhotoDB]

    public init(
        examinationNumber: String,
        patientName: String,
        patientGenderRawValue: String,
        patientDateOfBirth: Date,
        patientHeightCM: String,
        patientWeightKG: String,
        patientComplaints: String,
        examinationDescription: String,
        isPatientPreparedForExamination: Bool,
        photos: [USExaminationDraftPhotoDB],
    ) {
        self.examinationNumber = examinationNumber
        self.patientName = patientName
        self.patientGenderRawValue = patientGenderRawValue
        self.patientDateOfBirth = patientDateOfBirth
        self.patientHeightCM = patientHeightCM
        self.patientWeightKG = patientWeightKG
        self.patientComplaints = patientComplaints
        self.examinationDescription = examinationDescription
        self.isPatientPreparedForExamination = isPatientPreparedForExamination
        self.photos = photos
    }
}
