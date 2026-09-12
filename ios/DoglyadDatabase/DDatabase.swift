import Foundation
import SwiftData

public final class DDatabase: DDatabaseProtocol {
    let defaults: UserDefaults = .standard
    var container: ModelContainer
    public let examinationReports: DExaminationReportsStore
    public let examinationTemplates: DExaminationTemplatesStore

    public init() throws {
        let schema = Schema([
            NeuralModelSettingsDB.self,
            USExaminationReportDB.self,
            USExaminationDataDB.self,
            USExaminationScanPhotoDB.self,
            USExaminationModelReportDB.self,
            USExaminationTemplateDB.self,
        ])
        container = try ModelContainer(
            for: schema
        )
        examinationReports = DExaminationReportsStore(
            modelContainer: container
        )
        examinationTemplates = DExaminationTemplatesStore(
            modelContainer: container
        )
    }
}

extension DDatabase {
    func getBool(_ key: DUserDefaultsKey) -> Bool {
        defaults.bool(forKey: key.rawValue)
    }

    func getString(_ key: DUserDefaultsKey) -> String? {
        defaults.string(forKey: key.rawValue)
    }

    func getInt(_ key: DUserDefaultsKey) -> Int? {
        defaults.object(forKey: key.rawValue) as? Int
    }

    func getDouble(_ key: DUserDefaultsKey) -> Double? {
        guard defaults.object(forKey: key.rawValue) != nil else { return nil }
        return defaults.double(forKey: key.rawValue)
    }

    func setValue<T>(_ value: T, _ key: DUserDefaultsKey) -> Void {
        defaults.set(value, forKey: key.rawValue)
    }

    func removeValue(_ key: DUserDefaultsKey) {
        defaults.removeObject(forKey: key.rawValue)
    }
}
