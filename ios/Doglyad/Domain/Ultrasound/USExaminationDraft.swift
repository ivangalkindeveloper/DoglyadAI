import DoglyadDatabase
import Foundation
import UIKit

struct USExaminationDraft {
    let form: USExaminationDraftForm
    let photos: [USExaminationScanPhoto]
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
}

extension USExaminationDraft {
    static func fromDB(
        _ db: USExaminationDraftDB
    ) -> USExaminationDraft {
        USExaminationDraft(
            form: USExaminationDraftForm.fromDB(db),
            photos: db.photos
                .sorted { $0.position < $1.position }
                .compactMap { USExaminationScanPhoto.fromDraftDB($0) }
        )
    }
}

extension USExaminationDraftForm {
    static func fromDB(
        _ db: USExaminationDraftDB
    ) -> USExaminationDraftForm {
        USExaminationDraftForm(
            examinationNumber: db.examinationNumber,
            patientName: db.patientName,
            patientGender: PatientGender(rawValue: db.patientGenderRawValue) ?? .male,
            patientDateOfBirth: db.patientDateOfBirth,
            patientHeightCM: db.patientHeightCM,
            patientWeightKG: db.patientWeightKG,
            patientComplaints: db.patientComplaints,
            examinationDescription: db.examinationDescription
        )
    }

    func toDB(
        photos: [USExaminationDraftPhotoDB] = []
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
            photos: photos
        )
    }
}

private extension USExaminationScanPhoto {
    static func fromDraftDB(
        _ db: USExaminationDraftPhotoDB
    ) -> USExaminationScanPhoto? {
        guard let image = UIImage(data: db.data) else { return nil }

        return USExaminationScanPhoto(
            id: db.id,
            image: image,
            thumbnail: db.thumbnailData.flatMap { UIImage(data: $0) }
        )
    }

    func toDraftDB(
        position: Int
    ) -> USExaminationDraftPhotoDB? {
        guard let data = image.pngData() else { return nil }

        return USExaminationDraftPhotoDB(
            id: id,
            position: position,
            data: data,
            thumbnailData: thumbnail.jpegData(
                compressionQuality: Self.thumbnailCompressionQuality
            )
        )
    }
}

extension Array where Element == USExaminationScanPhoto {
    func toDraftDB() -> [USExaminationDraftPhotoDB] {
        enumerated().compactMap { index, photo in
            photo.toDraftDB(position: index)
        }
    }
}
