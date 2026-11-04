#if DEBUG
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "Генерация · ожидание первого токена",
    ) {
        ReportReceivedPreviewView(
            scenario: .waitingForFirstToken,
        )
        .previewable()
    }

    #Preview(
        "Генерация · первый токен",
    ) {
        ReportReceivedPreviewView(
            scenario: .firstToken,
        )
        .previewable()
    }

    #Preview(
        "Генерация · описание",
    ) {
        ReportReceivedPreviewView(
            scenario: .streamingDescription,
        )
        .previewable()
    }

    #Preview(
        "Генерация · заключение",
    ) {
        ReportReceivedPreviewView(
            scenario: .streamingConclusion,
        )
        .previewable()
    }

    #Preview(
        "Готовый протокол",
    ) {
        ReportReceivedPreviewView(
            scenario: .completed,
        )
        .previewable()
    }

    #Preview(
        "Готовый протокол · рекомендации и замечания",
    ) {
        ReportReceivedPreviewView(
            scenario: .completedWithRemarks,
        )
        .previewable()
    }

    #Preview(
        "Готовый протокол · из деталей",
    ) {
        ReportReceivedPreviewView(
            scenario: .fromReportDetail,
        )
        .previewable()
    }

    #Preview(
        "Готовый протокол · почта не задана",
    ) {
        ReportReceivedPreviewView(
            scenario: .withoutEmail,
        )
        .previewable()
    }

    #Preview(
        "Готовый протокол · почта требует Pro",
    ) {
        ReportReceivedPreviewView(
            scenario: .emailOffered,
        )
        .previewable()
    }

    #Preview(
        "Готовый протокол · отправка недоступна",
    ) {
        ReportReceivedPreviewView(
            scenario: .emailUnavailable,
        )
        .previewable()
    }

    #Preview(
        "Отправка на почту",
    ) {
        ReportReceivedPreviewView(
            scenario: .sendingEmail,
        )
        .previewable()
    }

    #Preview(
        "Ошибка отправки на почту",
    ) {
        ReportReceivedPreviewView(
            scenario: .deliveryFailed,
        )
        .previewable()
    }

    #Preview(
        "Генерация прервана · без текста",
    ) {
        ReportReceivedPreviewView(
            scenario: .interruptedWithoutText,
        )
        .previewable()
    }

    #Preview(
        "Генерация прервана · частичный текст",
    ) {
        ReportReceivedPreviewView(
            scenario: .interrupted,
        )
        .previewable()
    }

    #Preview(
        "Ошибка генерации · без текста",
    ) {
        ReportReceivedPreviewView(
            scenario: .failedWithoutText,
        )
        .previewable()
    }

    #Preview(
        "Ошибка генерации · частичный текст",
    ) {
        ReportReceivedPreviewView(
            scenario: .failed,
        )
        .previewable()
    }

    #Preview(
        "Генерация отменена",
    ) {
        ReportReceivedPreviewView(
            scenario: .cancelled,
        )
        .previewable()
    }
#endif
