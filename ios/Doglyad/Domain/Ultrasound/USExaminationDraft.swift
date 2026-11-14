import DoglyadDatabase
import Foundation
import UIKit

struct USExaminationDraft {
    let form: USExaminationDraftForm
    let photos: [USExaminationScanPhoto]

    init(
        form: USExaminationDraftForm,
        photos: [USExaminationScanPhoto],
    ) {
        self.form = form
        self.photos = photos
    }
}

struct USExaminationDraftForm: Equatable, Sendable {
    let examinationNumber: String
    let patientName: String
    let patientGender: PatientGender
    let patientDateOfBirth: Date
    let patientHeightCM: String
    let patientWeightKG: String
    let patientComplaints: String
    let examinationDescription: String
    let isPatientPreparedForExamination: Bool

    init(
        examinationNumber: String,
        patientName: String,
        patientGender: PatientGender,
        patientDateOfBirth: Date,
        patientHeightCM: String,
        patientWeightKG: String,
        patientComplaints: String,
        examinationDescription: String,
        isPatientPreparedForExamination: Bool,
    ) {
        self.examinationNumber = examinationNumber
        self.patientName = patientName
        self.patientGender = patientGender
        self.patientDateOfBirth = patientDateOfBirth
        self.patientHeightCM = patientHeightCM
        self.patientWeightKG = patientWeightKG
        self.patientComplaints = patientComplaints
        self.examinationDescription = examinationDescription
        self.isPatientPreparedForExamination = isPatientPreparedForExamination
    }
}

extension USExaminationDraft {
    static func fromDB(
        _ db: USExaminationDraftDB,
    ) -> USExaminationDraft {
        USExaminationDraft(
            form: USExaminationDraftForm.fromDB(
                db,
            ),
            photos: db.photos
                .sorted {
                    $0.position < $1.position
                }
                .compactMap {
                    USExaminationScanPhoto.fromDraftDB(
                        $0,
                    )
                },
        )
    }
}

extension USExaminationDraftForm {
    static func fromDB(
        _ db: USExaminationDraftDB,
    ) -> USExaminationDraftForm {
        USExaminationDraftForm(
            examinationNumber: db.examinationNumber,
            patientName: db.patientName,
            patientGender: PatientGender(
                rawValue: db.patientGenderRawValue,
            ) ?? .male,
            patientDateOfBirth: db.patientDateOfBirth,
            patientHeightCM: db.patientHeightCM,
            patientWeightKG: db.patientWeightKG,
            patientComplaints: db.patientComplaints,
            examinationDescription: db.examinationDescription,
            isPatientPreparedForExamination: db.isPatientPreparedForExamination,
        )
    }

    func toDB(
        photos: [USExaminationDraftPhotoDB] = [],
    ) -> USExaminationDraftDB {
        USExaminationDraftDB(
            examinationNumber: examinationNumber,
            patientName: patientName,
            patientGenderRawValue: patientGender.rawValue,
            patientDateOfBirth: patientDateOfBirth,
            patientHeightCM: patientHeightCM,
            patientWeightKG: patientWeightKG,
            patientComplaints: patientComplaints,
            examinationDescription: examinationDescription,
            isPatientPreparedForExamination: isPatientPreparedForExamination,
            photos: photos,
        )
    }
}
