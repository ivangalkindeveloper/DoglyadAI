import Foundation

public protocol DDatabaseUSExaminationTypeProtocol: AnyObject {
    func getSelectedUSExaminationTypeId() -> String?

    func setSelectedUSExaminationTypeId(
        value: String,
    )

    func getRecentUSExaminationTypeIds() -> [String]

    func setRecentUSExaminationTypeIds(
        values: [String],
    )
}
