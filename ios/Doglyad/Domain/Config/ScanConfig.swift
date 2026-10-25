import Foundation

struct ScanConfig: Codable, Equatable {
    let examinationNumberMaxLength: Int
    let patientNameMaxLength: Int
    let patientHeightCMMaxLength: Int
    let patientWeightKGMaxLength: Int
    let patientComplaintsMaxLength: Int
    let examinationDescriptionMaxLength: Int
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
