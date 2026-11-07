#if DEBUG
    import SwiftUI

    #Preview(
        "01 Загрузка",
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
        "02 Ошибка загрузки",
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
        "03 Без подписки",
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
        "04 Base · App Store",
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
        "05 Base · ЮКасса",
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
        "06 Pro · App Store",
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
        "07 Pro · ЮКасса",
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
        "08 Обновление подписки",
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
        "09 App Store · автопродление отключено",
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
        "10 Автопродление отключено",
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
        "11 Ошибка операции",
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
#endif
