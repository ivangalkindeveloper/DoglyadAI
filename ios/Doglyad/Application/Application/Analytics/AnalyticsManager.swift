import FirebaseAnalytics

@MainActor
final class AnalyticsManager {
    private static var isApplicationOpenedLogged = false

    private let isEnabled: Bool

    init(
        isEnabled: Bool = true,
    ) {
        self.isEnabled = isEnabled
    }

    func applicationOpened(
        environment: EnvironmentType,
        appVersion: String,
    ) {
        guard isEnabled, !Self.isApplicationOpenedLogged else { return }
        Self.isApplicationOpenedLogged = true

        log(
            event: .applicationOpened,
            parameters: AnalyticsParameters(
                [
                    .appVersion: .string(
                        appVersion,
                    ),
                    .environment: .string(
                        environment.rawValue,
                    ),
                ],
            ),
        )
    }

    func screenViewed(
        _ screen: AnalyticsScreen,
        parameters: AnalyticsParameters = .empty,
    ) {
        log(
            event: .screenViewed,
            parameters: AnalyticsParameters(
                [
                    .screen: .string(
                        screen.rawValue,
                    ),
                ],
            ).merging(
                parameters,
            ),
        )
    }

    func bottomSheetViewed(
        _ bottomSheet: AnalyticsBottomSheet,
        parameters: AnalyticsParameters = .empty,
    ) {
        log(
            event: .bottomSheetViewed,
            parameters: AnalyticsParameters(
                [
                    .bottomSheet: .string(
                        bottomSheet.rawValue,
                    ),
                ],
            ).merging(
                parameters,
            ),
        )
    }

    func buttonTapped(
        _ button: AnalyticsButton,
        parameters: AnalyticsParameters = .empty,
    ) {
        log(
            event: .buttonTapped,
            parameters: AnalyticsParameters(
                [
                    .button: .string(
                        button.rawValue,
                    ),
                ],
            ).merging(
                parameters,
            ),
        )
    }

    func actionCompleted(
        _ action: AnalyticsAction,
        parameters: AnalyticsParameters = .empty,
    ) {
        log(
            event: .actionCompleted,
            parameters: AnalyticsParameters(
                [
                    .action: .string(
                        action.rawValue,
                    ),
                ],
            ).merging(
                parameters,
            ),
        )
    }

    private func log(
        event: AnalyticsEvent,
        parameters: AnalyticsParameters,
    ) {
        guard isEnabled else { return }

        Analytics.logEvent(
            event.rawValue,
            parameters: parameters.firebaseParameters,
        )
    }
}
