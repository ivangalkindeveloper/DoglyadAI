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
        scanPhotoEncodingOptions: ScanPhotoEncodingOptions,
        l10n: L10N,
    ) -> ReportEmail {
        ReportEmail(
            recipientEmail: recipientEmail,
            subject: shareSubject(
                examinationTypesById: examinationTypesById,
                l10n: l10n,
            ),
            body: shareMessage(
                l10n: l10n,
            ),
            attachments: examinationData.photos.enumerated().compactMap { index, photo in
                guard let data = photo.encodedJPEGData(
                    options: scanPhotoEncodingOptions,
                ) else {
                    return nil
                }
                return ReportEmailAttachment(
                    fileName: "ultrasound-\(index + 1).jpg",
                    mimeType: "image/jpeg",
                    data: data,
                )
            },
        )
    }

    func shareSubject(
        examinationTypesById: [String: USExaminationType],
        l10n: L10N,
    ) -> String {
        let appName = String(
            localized: l10n[
                .appName,
            ],
        )
        let date = date.localized(
            locale: l10n.locale,
        )
        let patientName = examinationData.patientName
        let examinationType = String(
            localized: .forExaminationTypeById(
                types: examinationTypesById,
                id: examinationData.usExaminationTypeId,
            ),
        )
        return "\(appName): \(date) \(patientName) \(examinationType)"
    }

    func shareMessage(
        l10n: L10N,
    ) -> String {
        var lines: [String] = [
            "\(String(localized: l10n[.scanExaminationDateLabel]))\n\(date.localized(locale: l10n.locale))",
            "\(String(localized: l10n[.scanExaminationNumberLabel]))\n\(examinationData.examinationNumber)",
            "\(String(localized: l10n[.scanPatientNameLabel]))\n\(examinationData.patientName)",
            "\(String(localized: l10n[.scanPatientGenderLabel]))\n\(String(localized: l10n.forGender(examinationData.patientGender)))",
            "\(String(localized: l10n[.scanPatientDateOfBirthLabel]))\n\(examinationData.patientDateOfBirth.localized(locale: l10n.locale))",
            "\(String(localized: l10n[.scanExaminationDescriptionLabel]))\n\(examinationData.examinationDescription)",
        ]

        if let patientComplaints = examinationData.patientComplaints,
           !patientComplaints.isEmpty
        {
            lines.append(
                "\(String(localized: l10n[.scanPatientComplaintsLabel]))\n\(patientComplaints)",
            )
        }
        lines.append(
            "\(String(localized: l10n[.reportActualModelResponseTitle]))\n\(actualModelReport.plainText(l10n: l10n))",
        )

        if !previousModelReports.isEmpty {
            lines.append(
                String(
                    localized: l10n[
                        .reportPreviousModelResponsesTitle,
                    ],
                ),
            )
            for modelReport in previousModelReports {
                lines.append(
                    modelReport.plainText(
                        l10n: l10n,
                    ),
                )
            }
        }

        return lines.joined(
            separator: "\n\n",
        )
    }

    static func fromDB(
        _ db: USExaminationReportDB,
    ) -> USExaminationReport {
        USExaminationReport(
            id: db.id,
            date: db.date,
            neuralModelSettings: NeuralModelSettings.fromDB(
                db.neuralModelSettings,
            ),
            examinationData: USExaminationData.fromDB(
                db.examinationData,
            ),
            actualModelReport: USExaminationModelReport.fromDB(
                db.actualModelReport,
            ),
            previousModelReports: db.previousModelReports.map { USExaminationModelReport.fromDB(
                $0,
            ) },
        )
    }

    func toDB() -> USExaminationReportDB {
        USExaminationReportDB(
            id: id,
            date: date,
            neuralModelSettings: neuralModelSettings.toDB(),
            examinationData: examinationData.toDB(),
            actualModelReport: actualModelReport.toDB(),
            previousModelReports: previousModelReports.map { $0.toDB() },
        )
    }
}
