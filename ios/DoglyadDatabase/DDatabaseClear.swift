import Foundation

public protocol DDatabaseClearProtocol: AnyObject {
    func clearAll() async
}

extension DDatabase: DDatabaseClearProtocol {
    public func clearAll() async {
        for key in DUserDefaultsKey.allCases {
            removeValue(key)
        }

        try? await examinationReports.clearAllExaminationReports()
        try? await examinationTemplates.clearAllExaminationTemplates()
    }
}
