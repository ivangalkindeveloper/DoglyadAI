import Combine
import DoglyadUI
import SwiftUI

@MainActor
final class AboutViewModel: DModuleViewModel {
    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getNeuralModelSettings: @escaping () -> NeuralModelSettings,
        onRequestCountIncremented: @escaping () -> Void,
    ) {
        super.init(
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getNeuralModelSettings: getNeuralModelSettings,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .bottomSheet(
                .about,
            ),
        )
    }

    var contactEmail: String {
        container.applicationConfig.contactEmail
    }

    var version: String {
        container.version
    }

    func onTapEmail() {
        analytics.buttonTapped(
            .aboutEmail,
        )
    }

    var versionDescription: String { "\(l10n.text(.aboutVersionLabel)): \(version)" }

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
