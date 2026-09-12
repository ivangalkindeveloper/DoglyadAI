import Foundation

public protocol DDatabaseUSExaminationTypeProtocol: AnyObject {
    func getSelectedUSExaminationTypeId() -> String?

    func setSelectedUSExaminationTypeId(value: String)

    func getRecentUSExaminationTypeIds() -> [String]

    func setRecentUSExaminationTypeIds(values: [String])
}

extension DDatabase: DDatabaseUSExaminationTypeProtocol {
    public func getSelectedUSExaminationTypeId() -> String? {
        getString(.selectedUSExaminationTypeId)
    }

    public func setSelectedUSExaminationTypeId(value: String) {
        setValue(value, .selectedUSExaminationTypeId)
    }

    public func getRecentUSExaminationTypeIds() -> [String] {
        defaults.stringArray(forKey: DUserDefaultsKey.recentUSExaminationTypeIds.rawValue) ?? []
    }

    public func setRecentUSExaminationTypeIds(values: [String]) {
        setValue(values, .recentUSExaminationTypeIds)
    }
}
