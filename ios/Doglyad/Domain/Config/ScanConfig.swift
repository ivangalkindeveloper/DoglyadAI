import Foundation

struct ScanConfig: Codable, Equatable {
    let examinationNumberMaxLength: Int
    let patientNameMaxLength: Int
    let patientHeightCMMaxLength: Int
    let patientWeightKGMaxLength: Int
    let patientComplaintsMaxLength: Int
    let examinationDescriptionMaxLength: Int

    init(
        examinationNumberMaxLength: Int,
        patientNameMaxLength: Int,
        patientHeightCMMaxLength: Int,
        patientWeightKGMaxLength: Int,
        patientComplaintsMaxLength: Int,
        examinationDescriptionMaxLength: Int,
    ) {
        self.examinationNumberMaxLength = examinationNumberMaxLength
        self.patientNameMaxLength = patientNameMaxLength
        self.patientHeightCMMaxLength = patientHeightCMMaxLength
        self.patientWeightKGMaxLength = patientWeightKGMaxLength
        self.patientComplaintsMaxLength = patientComplaintsMaxLength
        self.examinationDescriptionMaxLength = examinationDescriptionMaxLength
    }
}

extension ScanConfig {
    // Placeholder configuration for previews/tests before server configuration is loaded.
    static let `default` = ScanConfig(
        examinationNumberMaxLength: .max,
        patientNameMaxLength: .max,
        patientHeightCMMaxLength: .max,
        patientWeightKGMaxLength: .max,
        patientComplaintsMaxLength: .max,
        examinationDescriptionMaxLength: .max,
    )
}
