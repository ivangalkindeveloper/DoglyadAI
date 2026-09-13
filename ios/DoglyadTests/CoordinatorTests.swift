@testable import Doglyad
import Foundation
import Testing

@MainActor
struct CoordinatorTests {
    @Test
    func initialRouteUsesNavigationPriority() {
        let onBoardingRoute = Coordinator.initialRoute(
            for: context(isOnBoardingCompleted: false)
        )
        #expect(onBoardingRoute.type == .onBoarding)

        let missingExaminationTypeRoute = Coordinator.initialRoute(
            for: context(selectedUSExaminationTypeId: nil)
        )
        #expect(missingExaminationTypeRoute.type == .onBoarding)

        let legalUpdateRoute = Coordinator.initialRoute(
            for: context(
                legalDate: Date(timeIntervalSince1970: 2),
                acceptedLegalDocumentDate: Date(timeIntervalSince1970: 1)
            )
        )
        #expect(legalUpdateRoute.type == .legalUpdate)

        let paywallRoute = Coordinator.initialRoute(
            for: context(conclusionsCount: 0, subscriptionStatus: nil)
        )
        #expect(paywallRoute.type == .subscriptionPaywall)

        let scanRoute = Coordinator.initialRoute(
            for: context(conclusionsCount: 1, subscriptionStatus: nil)
        )
        #expect(scanRoute.type == .scan)
    }

    private func context(
        isOnBoardingCompleted: Bool = true,
        selectedUSExaminationTypeId: String? = "type",
        legalDate: Date = .distantPast,
        acceptedLegalDocumentDate: Date? = .distantPast,
        conclusionsCount: Int = 1,
        subscriptionStatus: SubscriptionStatus? = nil
    ) -> InitialNavigationContext {
        return InitialNavigationContext(
            applicationConfig: applicationConfig(legalDate: legalDate),
            isOnBoardingCompleted: isOnBoardingCompleted,
            selectedUSExaminationTypeId: selectedUSExaminationTypeId,
            acceptedLegalDocumentDate: acceptedLegalDocumentDate,
            conclusionsCount: conclusionsCount,
            subscriptionStatus: subscriptionStatus
        )
    }

    private func applicationConfig(
        legalDate: Date = .distantPast
    ) -> ApplicationConfig {
        let defaultConfig = ApplicationConfig.default
        return ApplicationConfig(
            isServiceAvailable: true,
            appStoreId: "app-store-id",
            actualVersion: Version(major: 1, minor: 0, patch: 0),
            contactEmail: defaultConfig.contactEmail,
            appleUpdateUrl: defaultConfig.appleUpdateUrl,
            legalDate: legalDate,
            privacyPolicyUrl: defaultConfig.privacyPolicyUrl,
            termsAndConditionsUrl: defaultConfig.termsAndConditionsUrl,
            network: defaultConfig.network,
            entitlements: defaultConfig.entitlements,
            ultrasound: defaultConfig.ultrasound,
            history: defaultConfig.history
        )
    }
}
