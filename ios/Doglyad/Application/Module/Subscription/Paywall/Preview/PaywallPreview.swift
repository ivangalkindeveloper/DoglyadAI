#if DEBUG
    import SwiftUI

    #Preview(
        "01 PaywallLoadingState",
    ) {
        PaywallPreviewView(
            state: PaywallLoadingState(),
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
        "03 PaywallDefaultState",
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

    #Preview(
        "06 Обновление тарифов",
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
        "07 PaywallPurchasingState",
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
        "10 PaywallRestoringState",
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
        "11 Восстановление без каталога",
    ) {
        PaywallPreviewView(
            state: PaywallRestoringState(
                previousState: PaywallLoadingState(),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
