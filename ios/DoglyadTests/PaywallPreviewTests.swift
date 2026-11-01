#if DEBUG
    @testable import Doglyad
    import Foundation
    import Router
    import Testing

    @MainActor
    struct PaywallPreviewTests {
        @Test(
            arguments: ["ru", "en"],
        )
        func previewLoadsBackendStringsAndTariffsWithoutServices(
            code: String,
        ) async throws {
            let container = PaywallPreviewFactory.makeContainer(
                code: code,
            )
            let expected = try VoiceLocalizationTestSupport.l10n(
                code: code,
            )
            #expect(
                container.l10n.text(
                    .paywallTitle,
                ) == expected.text(
                    .paywallTitle,
                ),
            )
            #expect(
                container.l10n.locale.language.languageCode?.identifier == code,
            )
            let model = PaywallPreviewFactory.makeViewModel(
                container: container,
                router: DRouter(
                    initialRoute: RouteScreen(
                        type: .paywall,
                    ),
                ),
            )
            model.onAppear()
            await model.lastTask?.value
            let content = try #require(
                model.state as? PaywallDefaultState,
            )
            #expect(
                content.plans.count == 8,
            )
            #expect(
                content.displayedPlans.map(
                    \.period,
                ) == [.annual, .sixMonth, .monthly, .weekly],
            )
            #expect(
                content.selectedPlan?.id == "pro_annual" && model.isContinueEnabled,
            )
            #expect(
                try #require(
                    content.selectedPlan,
                ).title == (code == "ru" ? "Pro - Годовой доступ" : "Pro - Annual access"),
            )
            #expect(
                try !#require(
                    content.selectedPlan,
                ).price.contains(
                    "{price}",
                ),
            )
            model.onSelectType(
                .base,
            )
            let base = try #require(
                model.state as? PaywallDefaultState,
            )
            #expect(
                base.displayedPlans.count == 4 && base.selectedPlan?.id == "base_annual",
            )
            #expect(
                content.selectedType == .pro && content.selectedPlan?.id == "pro_annual",
            )
            #expect(
                content.tiers.count == 2 && content.selectedTier?.features.count == 3,
            )
            #expect(
                base.selectedTier?.features.count == 1,
            )
            #expect(
                content.selectedTier?.title == (code == "ru" ? "Подписка Pro" : "Subscription Pro"),
            )
            model.onTapContinue()
            for _ in 0 ..< 50 {
                switch model.state {
                case _ as PaywallPurchasingState: await Task.yield()
                default: break
                }
            }
            #expect(
                model.state is PaywallContentState,
            )
        }

        @Test
        func sharedPreviewContainerDisplaysBackendText() throws {
            let container = DependencyContainer.previewable
            let expected = try VoiceLocalizationTestSupport.l10n(
                code: "ru",
            )
            #expect(
                container.l10n.text(
                    .paywallDescription,
                ) == expected.text(
                    .paywallDescription,
                ),
            )
        }
    }
#endif
