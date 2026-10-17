import Router

final class PermissionArguments: RouteArgumentsProtocol {
    let kind: Kind

    init(
        kind: Kind,
    ) {
        self.kind = kind
    }

    enum Kind {
        case camera
        case photoLibrary
        case speech

        var analyticsDestination: AnalyticsBottomSheet {
            switch self {
            case .camera: .permissionCamera
            case .photoLibrary: .permissionPhotoLibrary
            case .speech: .permissionSpeech
            }
        }
    }
}
