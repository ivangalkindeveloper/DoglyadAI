import Combine
import DoglyadUI
import SwiftUI

@MainActor
final class AboutViewModel: DModuleViewModel<any AboutStateProtocol> {
    let contactEmail: String
    let version: String
    let versionDescription: String

    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRefreshSubscriptionStatus: @escaping () async -> Void,
    ) {
        contactEmail = container.applicationConfig.contactEmail
        version = container.version
        versionDescription = "\(container.l10n.text(.aboutVersionLabel)): \(container.version)"
        super.init(
            state: AboutDefaultState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getSettingsAI: getSettingsAI,
            onRefreshSubscriptionStatus: onRefreshSubscriptionStatus,
            analyticsDestination: .bottomSheet(
                .about,
            ),
        )
    }

    func onTapEmail() {
        analytics.buttonTapped(
            .aboutEmail,
        )
    }

    func contactAttributedText(
        theme: DTheme,
    ) -> AttributedString {
        var description = AttributedString(
            l10n.text(
                .aboutContactDescription,
            ),
        )
        description.font = theme.typography.textSmall
        description.foregroundColor = theme.color.grayscaleHeader
        var email = AttributedString(
            contactEmail,
        )
        email.font = theme.typography.textSmall
        email.foregroundColor = theme.color.primaryDefault
        email.link = URL(
            string: "mailto:\(contactEmail)",
        )
        return description + " " + email
    }
}
