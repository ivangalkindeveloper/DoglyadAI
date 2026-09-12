import DoglyadDatabase
import Foundation

struct USExaminationData: Codable {
    let usExaminationTypeId: String
    let photos: [USExaminationScanPhoto]
    let patientName: String
    let patientGender: PatientGender
    let patientDateOfBirth: Date
    let patientHeight: Double
    let patientWeight: Double
    let patientComplaint: String?
    let examinationDescription: String
}

extension USExaminationData {
    static func fromDB(
        _ db: USExaminationDataDB
    ) -> USExaminationData {
        USExaminationData(
            usExaminationTypeId: db.usExaminationTypeId,
            photos: db.photos.map { USExaminationScanPhoto.fromDB($0) },
            patientName: db.patientName,
            patientGender: PatientGender(rawValue: db.patientGenderRawValue) ?? .male,
            patientDateOfBirth: db.patientDateOfBirth,
            patientHeight: db.patientHeight,
            patientWeight: db.patientWeight,
            patientComplaint: db.patientComplaint,
            examinationDescription: db.examinationDescription
        )
    }

    func toDB() -> USExaminationDataDB {
        USExaminationDataDB(
            usExaminationTypeId: usExaminationTypeId,
            photos: photos.map { $0.toDB() },
            patientName: patientName,
            patientGenderRawValue: patientGender.rawValue,
            patientDateOfBirth: patientDateOfBirth,
            patientHeight: patientHeight,
            patientWeight: patientWeight,
            patientComplaint: patientComplaint,
            examinationDescription: examinationDescription
        )
    }
}
