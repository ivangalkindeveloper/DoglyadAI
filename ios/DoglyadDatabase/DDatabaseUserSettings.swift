import Foundation

public protocol DDatabaseUserSettingsProtocol: AnyObject {
    func getUserEmail() -> String?

    func setUserEmail(value: String)

    func getIncludeRecommendations() -> Bool

    func setIncludeRecommendations(value: Bool)
}

extension DDatabase: DDatabaseUserSettingsProtocol {
    public func getUserEmail() -> String? {
        getString(.userEmail)
    }

    public func setUserEmail(value: String) {
        setValue(value, .userEmail)
    }

    public func getIncludeRecommendations() -> Bool {
        guard defaults.object(forKey: DUserDefaultsKey.includeRecommendations.rawValue) != nil else {
            return true
        }
        return getBool(.includeRecommendations)
    }

    public func setIncludeRecommendations(value: Bool) {
        setValue(value, .includeRecommendations)
    }
}
