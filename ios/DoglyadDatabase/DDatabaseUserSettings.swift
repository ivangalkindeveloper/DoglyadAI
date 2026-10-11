import Foundation

public protocol DDatabaseUserSettingsProtocol: AnyObject {
    func getIsPhotoRemarks() -> Bool
    func setIsPhotoRemarks(
        value: Bool,
    )
    func getIsDescriptionRemarks() -> Bool
    func setIsDescriptionRemarks(
        value: Bool,
    )
    func getIsRemarksVisible() -> Bool
    func setIsRemarksVisible(
        value: Bool,
    )
    func getUserEmail() -> String?

    func setUserEmail(
        value: String?,
    )

    func getIncludeRecommendations() -> Bool

    func setIncludeRecommendations(
        value: Bool,
    )
}

extension DDatabase: DDatabaseUserSettingsProtocol {
    public func getIsPhotoRemarks() -> Bool {
        getUserSettingsFlag(
            .isPhotoRemarks,
        )
    }

    public func setIsPhotoRemarks(
        value: Bool,
    ) {
        setValue(
            value,
            .isPhotoRemarks,
        )
    }

    public func getIsDescriptionRemarks() -> Bool {
        getUserSettingsFlag(
            .isDescriptionRemarks,
        )
    }

    public func setIsDescriptionRemarks(
        value: Bool,
    ) {
        setValue(
            value,
            .isDescriptionRemarks,
        )
    }

    public func getIsRemarksVisible() -> Bool {
        getUserSettingsFlag(
            .isRemarksVisible,
        )
    }

    public func setIsRemarksVisible(
        value: Bool,
    ) {
        setValue(
            value,
            .isRemarksVisible,
        )
    }

    private func getUserSettingsFlag(
        _ key: DUserDefaultsKey,
    ) -> Bool {
        guard defaults.object(
            forKey: key.rawValue,
        ) != nil else { return true }
        return getBool(
            key,
        )
    }

    public func getUserEmail() -> String? {
        getString(
            .userEmail,
        )
    }

    public func setUserEmail(
        value: String?,
    ) {
        if let value {
            setValue(
                value,
                .userEmail,
            )
        } else {
            removeValue(
                .userEmail,
            )
        }
    }

    public func getIncludeRecommendations() -> Bool {
        guard defaults.object(
            forKey: DUserDefaultsKey.includeRecommendations.rawValue,
        ) != nil else {
            return true
        }
        return getBool(
            .includeRecommendations,
        )
    }

    public func setIncludeRecommendations(
        value: Bool,
    ) {
        setValue(
            value,
            .includeRecommendations,
        )
    }
}
