#if DEBUG
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 Генерация · ожидание первого токена",
    ) {
        ReportReceivedPreviewView(
            scenario: .waitingForFirstToken,
        )
        .previewable()
    }

    #Preview(
        "02 Генерация · первый токен",
    ) {
        ReportReceivedPreviewView(
            scenario: .firstToken,
        )
        .previewable()
    }

    #Preview(
        "03 Генерация · описание",
    ) {
        ReportReceivedPreviewView(
            scenario: .streamingDescription,
        )
        .previewable()
    }

    #Preview(
        "04 Генерация · заключение",
    ) {
        ReportReceivedPreviewView(
            scenario: .streamingConclusion,
        )
        .previewable()
    }

    #Preview(
        "05 Готовый протокол",
    ) {
        ReportReceivedPreviewView(
            scenario: .completed,
        )
        .previewable()
    }

    #Preview(
        "06 Готовый протокол · рекомендации и замечания",
    ) {
        ReportReceivedPreviewView(
            scenario: .completedWithRemarks,
        )
        .previewable()
    }

    #Preview(
        "07 Готовый протокол · из деталей",
    ) {
        ReportReceivedPreviewView(
            scenario: .fromReportDetail,
        )
        .previewable()
    }

    #Preview(
        "08 Готовый протокол · почта не задана",
    ) {
        ReportReceivedPreviewView(
            scenario: .withoutEmail,
        )
        .previewable()
    }

    #Preview(
        "09 Готовый протокол · почта требует Pro",
    ) {
        ReportReceivedPreviewView(
            scenario: .emailOffered,
        )
        .previewable()
    }

    #Preview(
        "10 Готовый протокол · отправка недоступна",
    ) {
        ReportReceivedPreviewView(
            scenario: .emailUnavailable,
        )
        .previewable()
    }

    #Preview(
        "11 Отправка на почту",
    ) {
        ReportReceivedPreviewView(
            scenario: .sendingEmail,
        )
        .previewable()
    }

    #Preview(
        "12 Ошибка отправки на почту",
    ) {
        ReportReceivedPreviewView(
            scenario: .deliveryFailed,
        )
        .previewable()
    }

    #Preview(
        "13 Генерация прервана · без текста",
    ) {
        ReportReceivedPreviewView(
            scenario: .interruptedWithoutText,
        )
        .previewable()
    }

    #Preview(
        "14 Генерация прервана · частичный текст",
    ) {
        ReportReceivedPreviewView(
            scenario: .interrupted,
        )
        .previewable()
    }

    #Preview(
        "15 Ошибка генерации · без текста",
    ) {
        ReportReceivedPreviewView(
            scenario: .failedWithoutText,
        )
        .previewable()
    }

    #Preview(
        "16 Ошибка генерации · частичный текст",
    ) {
        ReportReceivedPreviewView(
            scenario: .failed,
        )
        .previewable()
    }

    #Preview(
        "17 Генерация отменена",
    ) {
        ReportReceivedPreviewView(
            scenario: .cancelled,
        )
        .previewable()
    }
#endif
