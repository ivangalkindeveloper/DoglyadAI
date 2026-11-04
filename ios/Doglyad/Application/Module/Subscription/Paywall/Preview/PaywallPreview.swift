#if DEBUG
    import SwiftUI

    #Preview(
        "Русский",
    ) {
        PaywallPreviewView()
            .previewable(
                container: PaywallPreviewFactory.makeContainer(
                    code: "ru",
                ),
            )
    }

    #Preview(
        "English",
    ) {
        PaywallPreviewView()
            .previewable(
                container: PaywallPreviewFactory.makeContainer(
                    code: "en",
                ),
            )
    }

    #Preview(
        "PaywallLoadingState",
    ) {
        PaywallPreviewView(
            state: PaywallLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "PaywallDefaultState",
    ) {
        PaywallPreviewView(
            state: ModulePreviewFactory.paywallContent,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "PaywallLoadingFailedState",
    ) {
        PaywallPreviewView(
            state: PaywallLoadingFailedState(
                errorDescription: "Не удалось загрузить тарифы. Проверьте подключение к интернету.",
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "PaywallOperationFailedState",
    ) {
        PaywallPreviewView(
            state: PaywallOperationFailedState(
                previousState: ModulePreviewFactory.paywallContent,
                errorDescription: "Не удалось завершить оплату. Повторите попытку.",
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "PaywallPurchasingState",
    ) {
        PaywallPreviewView(
            state: PaywallPurchasingState(
                content: ModulePreviewFactory.paywallContent,
                plan: ModulePreviewFactory.paywallPlan,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "PaywallPendingState",
    ) {
        PaywallPreviewView(
            state: PaywallPendingState(
                content: ModulePreviewFactory.paywallContent,
                plan: ModulePreviewFactory.paywallPlan,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "PaywallRestoringState",
    ) {
        PaywallPreviewView(
            state: PaywallRestoringState(
                previousState: ModulePreviewFactory.paywallContent,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "Обновление тарифов",
    ) {
        PaywallPreviewView(
            state: PaywallLoadingState(
                previousState: ModulePreviewFactory.paywallContent,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "Восстановление без каталога",
    ) {
        PaywallPreviewView(
            state: PaywallRestoringState(
                previousState: PaywallLoadingState(),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "Каталог без предложений",
    ) {
        PaywallPreviewView(
            state: PaywallDefaultState(
                tiers: [],
                plans: [],
                selectedType: .pro,
                selectedPlanID: nil,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
