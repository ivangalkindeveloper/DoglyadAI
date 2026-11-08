#if DEBUG
    import SwiftUI

    #Preview(
        "01 PaywallCatalogLoadingState",
    ) {
        PaywallPreviewView(
            state: PaywallCatalogLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 PaywallLoadingFailedState",
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
        "03 PaywallSuccessState",
    ) {
        PaywallPreviewView(
            state: ModulePreviewFactory.paywallContent,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 Русский",
    ) {
        PaywallPreviewView()
            .previewable(
                container: PaywallPreviewFactory.makeContainer(
                    code: "ru",
                ),
            )
    }

    #Preview(
        "05 Каталог без предложений",
    ) {
        PaywallPreviewView(
            state: PaywallSuccessState(
                tiers: [],
                plans: [],
                selectedType: .pro,
                selectedPlanID: nil,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "06 Обновление тарифов",
    ) {
        PaywallPreviewView(
            state: PaywallCatalogLoadingState(
                previousState: ModulePreviewFactory.paywallContent,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "07 PaywallPurchaseLoadingState",
    ) {
        PaywallPreviewView(
            state: PaywallPurchaseLoadingState(
                content: ModulePreviewFactory.paywallContent,
                plan: ModulePreviewFactory.paywallPlan,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "08 PaywallPendingState",
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
        "09 PaywallOperationFailedState",
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
        "10 PaywallPaymentCheckLoadingState",
    ) {
        PaywallPreviewView(
            state: PaywallPaymentCheckLoadingState(
                previousState: PaywallPendingState(
                    content: ModulePreviewFactory.paywallContent,
                    plan: ModulePreviewFactory.paywallPlan,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "11 PaywallRestoreLoadingState",
    ) {
        PaywallPreviewView(
            state: PaywallRestoreLoadingState(
                previousState: ModulePreviewFactory.paywallContent,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "12 Восстановление без каталога",
    ) {
        PaywallPreviewView(
            state: PaywallRestoreLoadingState(
                previousState: PaywallCatalogLoadingState(),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
