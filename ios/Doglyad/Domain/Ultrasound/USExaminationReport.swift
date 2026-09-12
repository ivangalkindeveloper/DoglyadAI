import DoglyadDatabase
import Foundation

struct USExaminationReport: Identifiable, Codable {
    var id: UUID = .init()
    let date: Date
    let neuralModelSettings: NeuralModelSettings
    let examinationData: USExaminationData
    let actualModelReport: USExaminationModelReport
    let previousModelReports: [USExaminationModelReport]
}

private extension USExaminationReport {
    enum CodingKeys: String, CodingKey {
        case date,
             neuralModelSettings,
             examinationData,
             actualModelReport,
             previousModelReports
    }
}

extension USExaminationReport {
    func makeEmail(
        recipientEmail: String,
        examinationTypesById: [String: USExaminationType],
        scanPhotoEncodingOptions: ScanPhotoEncodingOptions
    ) -> ReportEmail {
        ReportEmail(
            recipientEmail: recipientEmail,
            subject: shareSubject(examinationTypesById: examinationTypesById),
            body: shareMessage,
            attachments: examinationData.photos.enumerated().compactMap { index, photo in
                guard let data = photo.encodedJPEGData(options: scanPhotoEncodingOptions) else {
                    return nil
                }
                return ReportEmailAttachment(
                    fileName: "ultrasound-\(index + 1).jpg",
                    mimeType: "image/jpeg",
                    data: data
                )
            }
        )
    }

    func shareSubject(
        examinationTypesById: [String: USExaminationType],
        locale: Locale = .current
    ) -> String {
        let appName = String(localized: .appName)
        let date = date.localized()
        let patientName = examinationData.patientName
        let examinationType = String(
            localized: .forExaminationTypeById(
                types: examinationTypesById,
                id: examinationData.usExaminationTypeId,
                locale: locale
            )
        )
        return "\(appName): \(date) \(patientName) \(examinationType)"
    }

    var shareMessage: String {
        var lines: [String] = [
            "\(String(localized: .scanExaminationDateLabel))\n\(date.localized())",
            "\(String(localized: .scanPatientNameLabel))\n\(examinationData.patientName)",
            "\(String(localized: .scanPatientGenderLabel))\n\(String(localized: .forGender(examinationData.patientGender)))",
            "\(String(localized: .scanPatientDateOfBirthLabel))\n\(examinationData.patientDateOfBirth.localized())",
            "\(String(localized: .scanExaminationDescriptionLabel))\n\(examinationData.examinationDescription)",
        ]

        if let patientComplaint = examinationData.patientComplaint,
           !patientComplaint.isEmpty
        {
            lines.append("\(String(localized: .scanPatientComplaintLabel))\n\(patientComplaint)")
        }
        lines.append("\(String(localized: .reportActualModelResponseTitle))\n\(actualModelReport.plainText)")

        if !previousModelReports.isEmpty {
            lines.append(String(localized: .reportPreviousModelResponsesTitle))
            for modelReport in previousModelReports {
                lines.append(modelReport.plainText)
            }
        }

        return lines.joined(separator: "\n\n")
    }

    static func fromDB(
        _ db: USExaminationReportDB
    ) -> USExaminationReport {
        USExaminationReport(
            id: db.id,
            date: db.date,
            neuralModelSettings: NeuralModelSettings.fromDB(db.neuralModelSettings),
            examinationData: USExaminationData.fromDB(db.examinationData),
            actualModelReport: USExaminationModelReport.fromDB(db.actualModelReport),
            previousModelReports: db.previousModelReports.map { USExaminationModelReport.fromDB($0) }
        )
    }

    func toDB() -> USExaminationReportDB {
        USExaminationReportDB(
            id: id,
            date: date,
            neuralModelSettings: neuralModelSettings.toDB(),
            examinationData: examinationData.toDB(),
            actualModelReport: actualModelReport.toDB(),
            previousModelReports: previousModelReports.map { $0.toDB() }
        )
    }
}
