#if DEBUG
    import SwiftUI

    #Preview(
        "Начальное состояние",
    ) {
        SubscriptionRecoveryPreviewView(
            state: SubscriptionRecoveryDefaultState(),
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "Создан ключ",
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
        "Восстановление",
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
        "Ошибка",
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
        "Создание ключа",
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
        "Ошибка · ключ сохранён",
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
