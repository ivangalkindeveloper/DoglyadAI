import DoglyadDatabase
import Foundation

struct USExaminationData: Codable, Equatable {
    let usExaminationTypeId: String
    let photos: [USExaminationScanPhoto]
    let examinationNumber: String
    let patientName: String
    let patientGender: PatientGender
    let patientDateOfBirth: Date
    let patientHeight: Double?
    let patientWeight: Double?
    let patientComplaints: String?
    let examinationDescription: String
    let isPatientPreparedForExamination: Bool
    let isPatientConsent: Bool
}

extension USExaminationData {
    static func fromDB(
        _ db: USExaminationDataDB,
    ) -> USExaminationData {
        USExaminationData(
            usExaminationTypeId: db.usExaminationTypeId,
            photos: db.photos.map {
                USExaminationScanPhoto.fromDB(
                    $0,
                )
            },
            examinationNumber: db.examinationNumber,
            patientName: db.patientName,
            patientGender: PatientGender(
                rawValue: db.patientGenderRawValue,
            ) ?? .male,
            patientDateOfBirth: db.patientDateOfBirth,
            patientHeight: db.patientHeight,
            patientWeight: db.patientWeight,
            patientComplaints: db.patientComplaints,
            examinationDescription: db.examinationDescription,
            isPatientPreparedForExamination: db.isPatientPreparedForExamination,
            isPatientConsent: db.isPatientConsent,
        )
    }

    func toDB() -> USExaminationDataDB {
        USExaminationDataDB(
            usExaminationTypeId: usExaminationTypeId,
            photos: photos.map {
                $0.toDB()
            },
            examinationNumber: examinationNumber,
            patientName: patientName,
            patientGenderRawValue: patientGender.rawValue,
            patientDateOfBirth: patientDateOfBirth,
            patientHeight: patientHeight,
            patientWeight: patientWeight,
            patientComplaints: patientComplaints,
            examinationDescription: examinationDescription,
            isPatientPreparedForExamination: isPatientPreparedForExamination,
            isPatientConsent: isPatientConsent,
        )
    }
}
