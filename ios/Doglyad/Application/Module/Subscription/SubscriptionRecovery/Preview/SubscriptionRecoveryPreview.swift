#if DEBUG
    import SwiftUI

    #Preview(
        "01 Начальное состояние",
    ) {
        SubscriptionRecoveryPreviewView(
            state: SubscriptionRecoveryDefaultState(),
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 Создание ключа",
    ) {
        SubscriptionRecoveryPreviewView(
            state: SubscriptionRecoveryLoadingState(
                previousState: SubscriptionRecoveryDefaultState(),
            ),
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "03 Создан ключ",
    ) {
        SubscriptionRecoveryPreviewView(
            state: SubscriptionRecoveryKeyState(
                key: "Preview-MixedCase-Recovery-Key",
            ),
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 Восстановление",
    ) {
        SubscriptionRecoveryPreviewView(
            state: SubscriptionRecoveryLoadingState(
                previousState: SubscriptionRecoveryKeyState(
                    key: "Preview-MixedCase-Recovery-Key",
                ),
            ),
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "05 Ошибка",
    ) {
        SubscriptionRecoveryPreviewView(
            state: SubscriptionRecoveryFailedState(
                previousState: SubscriptionRecoveryDefaultState(),
                errorDescription: L10NPreviewFactory.make().text(
                    .subscriptionRecoveryFailedDescription,
                ),
            ),
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "06 Ошибка · ключ сохранён",
    ) {
        SubscriptionRecoveryPreviewView(
            state: SubscriptionRecoveryFailedState(
                previousState: SubscriptionRecoveryKeyState(
                    key: "Preview-MixedCase-Recovery-Key",
                ),
                errorDescription: "Не удалось восстановить подписку.",
            ),
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(),
        )
    }
#endif
