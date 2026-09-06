@testable import Doglyad
import Foundation
import Testing

@MainActor
struct CoordinatorTests {
    @Test
    func initialRouteUsesNavigationPriority() throws {
        let updateRoute = try Coordinator.initialRoute(
            for: context(
                applicationVersion: Version(major: 1, minor: 0, patch: 0),
                actualVersion: Version(major: 2, minor: 0, patch: 0),
                isOnBoardingCompleted: false
            )
        )
        #expect(updateRoute.type == .newVersion)

        let onBoardingRoute = try Coordinator.initialRoute(
            for: context(isOnBoardingCompleted: false)
        )
        #expect(onBoardingRoute.type == .onBoarding)

        let missingExaminationTypeRoute = try Coordinator.initialRoute(
            for: context(selectedUSExaminationTypeId: nil)
        )
        #expect(missingExaminationTypeRoute.type == .onBoarding)

        let legalUpdateRoute = try Coordinator.initialRoute(
            for: context(
                legalDate: Date(timeIntervalSince1970: 2),
                acceptedLegalDocumentDate: Date(timeIntervalSince1970: 1)
            )
        )
        #expect(legalUpdateRoute.type == .legalUpdate)

        let paywallRoute = try Coordinator.initialRoute(
            for: context(conclusionsCount: 0, subscriptionStatus: nil)
        )
        #expect(paywallRoute.type == .subscriptionPaywall)

        let scanRoute = try Coordinator.initialRoute(
            for: context(conclusionsCount: 1, subscriptionStatus: nil)
        )
        #expect(scanRoute.type == .scan)
    }

    @Test
    func unavailableServiceFailsBeforeSelectingRoute() {
        #expect(throws: InitializationError.self) {
            try Coordinator.initialRoute(
                for: context(isServiceAvailable: false)
            )
        }
    }

    private func context(
        isServiceAvailable: Bool = true,
        applicationVersion: Version = Version(major: 1, minor: 0, patch: 0),
        actualVersion: Version = Version(major: 1, minor: 0, patch: 0),
        isOnBoardingCompleted: Bool = true,
        selectedUSExaminationTypeId: String? = "type",
        legalDate: Date = .distantPast,
        acceptedLegalDocumentDate: Date? = .distantPast,
        conclusionsCount: Int = 1,
        subscriptionStatus: SubscriptionStatus? = nil
    ) -> InitialNavigationContext {
        let defaultConfig = ApplicationConfig.default
        return InitialNavigationContext(
            applicationConfig: ApplicationConfig(
                isServiceAvailable: isServiceAvailable,
                appStoreId: "app-store-id",
                actualVersion: actualVersion,
                contactEmail: defaultConfig.contactEmail,
                appleUpdateUrl: defaultConfig.appleUpdateUrl,
                legalDate: legalDate,
                privacyPolicyUrl: defaultConfig.privacyPolicyUrl,
                termsAndConditionsUrl: defaultConfig.termsAndConditionsUrl,
                network: defaultConfig.network,
                entitlements: defaultConfig.entitlements,
                ultrasound: defaultConfig.ultrasound,
                history: defaultConfig.history
            ),
            applicationVersion: applicationVersion,
            isOnBoardingCompleted: isOnBoardingCompleted,
            selectedUSExaminationTypeId: selectedUSExaminationTypeId,
            acceptedLegalDocumentDate: acceptedLegalDocumentDate,
            conclusionsCount: conclusionsCount,
            subscriptionStatus: subscriptionStatus
        )
    }
}
