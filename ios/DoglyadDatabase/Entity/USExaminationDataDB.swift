import Foundation
import SwiftData

@Model
public final class USExaminationDataDB {
    public var usExaminationTypeId: String
    @Relationship(
        deleteRule: .cascade,
    ) public var photos: [USExaminationScanPhotoDB]
    public var examinationNumber: String
    public var patientName: String
    public var patientGenderRawValue: String
    public var patientDateOfBirth: Date
    public var isPatientConsent: Bool = false
    public var patientHeight: Double?
    public var patientWeight: Double?
    public var patientComplaints: String?
    public var examinationDescription: String

    public init(
        usExaminationTypeId: String,
        photos: [USExaminationScanPhotoDB] = [],
        examinationNumber: String,
        patientName: String,
        patientGenderRawValue: String,
        patientDateOfBirth: Date,
        isPatientConsent: Bool,
        patientHeight: Double?,
        patientWeight: Double?,
        patientComplaints: String?,
        examinationDescription: String,
    ) {
        self.usExaminationTypeId = usExaminationTypeId
        self.photos = photos
        self.examinationNumber = examinationNumber
        self.patientName = patientName
        self.patientGenderRawValue = patientGenderRawValue
        self.patientDateOfBirth = patientDateOfBirth
        self.isPatientConsent = isPatientConsent
        self.patientHeight = patientHeight
        self.patientWeight = patientWeight
        self.patientComplaints = patientComplaints
        self.examinationDescription = examinationDescription
    }
}
