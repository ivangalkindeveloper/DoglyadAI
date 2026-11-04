#if DEBUG
    import SwiftUI

    #Preview(
        "Pro · App Store",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .applePro,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
    }

    #Preview(
        "Base · App Store",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .appleBase,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
    }

    #Preview(
        "App Store · автопродление отключено",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .appleRenewalOff,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
    }

    #Preview(
        "Base · ЮКасса",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .yooKassaBase,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
    }

    #Preview(
        "Pro · ЮКасса",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .yooKassaPro,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
    }

    #Preview(
        "Автопродление отключено",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .renewalOff,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
    }

    #Preview(
        "Без подписки",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .inactive,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
    }

    #Preview(
        "Загрузка",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .loading,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
    }

    #Preview(
        "Обновление подписки",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .updating,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
    }

    #Preview(
        "Ошибка загрузки",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .failed,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
    }

    #Preview(
        "Ошибка операции",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .operationFailed,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
    }

    #Preview(
        "Pro · English",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .applePro,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "en",
            ),
        )
    }
#endif
