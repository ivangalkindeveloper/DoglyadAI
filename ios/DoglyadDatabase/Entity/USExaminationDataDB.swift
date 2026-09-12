import Foundation
import SwiftData

@Model
public final class USExaminationDataDB {
    public var usExaminationTypeId: String
    @Relationship public var photos: [USExaminationScanPhotoDB]
    public var patientName: String
    public var patientGenderRawValue: String
    public var patientDateOfBirth: Date
    public var patientHeight: Double
    public var patientWeight: Double
    public var patientComplaint: String?
    public var examinationDescription: String

    public init(
        usExaminationTypeId: String,
        photos: [USExaminationScanPhotoDB] = [],
        patientName: String,
        patientGenderRawValue: String,
        patientDateOfBirth: Date,
        patientHeight: Double,
        patientWeight: Double,
        patientComplaint: String?,
        examinationDescription: String
    ) {
        self.usExaminationTypeId = usExaminationTypeId
        self.photos = photos
        self.patientName = patientName
        self.patientGenderRawValue = patientGenderRawValue
        self.patientDateOfBirth = patientDateOfBirth
        self.patientHeight = patientHeight
        self.patientWeight = patientWeight
        self.patientComplaint = patientComplaint
        self.examinationDescription = examinationDescription
    }
}
