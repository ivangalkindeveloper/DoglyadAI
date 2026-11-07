public struct DPhotoCardConfiguration {
    public let badge: Badge?

    public init(
        badge: Badge? = nil,
    ) {
        self.badge = badge
    }

    public var isBadgeVisible: Bool {
        badge != nil
    }

    public enum Badge {
        case delete(action: () -> Void)
        case warning
    }
}
