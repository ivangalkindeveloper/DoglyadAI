#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 Проверка модели",
    ) {
        ScanSpeechPreviewView(
            state: ScanSpeechPreparingModelState(
                preparation: .checking,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 Загрузка без прогресса",
    ) {
        ScanSpeechPreviewView(
            state: ScanSpeechPreparingModelState(
                preparation: .downloading(
                    progress: nil,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "03 ScanSpeechPreparingModelState",
    ) {
        ScanSpeechPreviewView(
            state: ScanSpeechPreparingModelState(
                preparation: .downloading(
                    progress: 0.45,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 Загрузка модели в память",
    ) {
        ScanSpeechPreviewView(
            state: ScanSpeechPreparingModelState(
                preparation: .loading,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "05 ScanSpeechModelPreparationFailedState",
    ) {
        ScanSpeechPreviewView(
            state: ScanSpeechModelPreparationFailedState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "06 ScanSpeechReadyState",
    ) {
        ScanSpeechPreviewView(
            state: ScanSpeechReadyState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "07 ScanSpeechPreparingRecordingState",
    ) {
        ScanSpeechPreviewView(
            state: ScanSpeechPreparingRecordingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "08 ScanSpeechRecordingState",
    ) {
        ScanSpeechPreviewView(
            state: ScanSpeechRecordingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "09 ScanSpeechTranscribingState",
    ) {
        ScanSpeechPreviewView(
            state: ScanSpeechTranscribingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "10 ScanSpeechAutomaticParsingState",
    ) {
        ScanSpeechPreviewView(
            state: ScanSpeechAutomaticParsingState(
                parsedText: USExaminationReportPreviewFactory.description,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "11 ScanSpeechReviewTranscriptState",
    ) {
        ScanSpeechPreviewView(
            state: ScanSpeechReviewTranscriptState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "12 ScanSpeechReviewParsingState",
    ) {
        ScanSpeechPreviewView(
            state: ScanSpeechReviewParsingState(
                parsedText: USExaminationReportPreviewFactory.description,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "13 Нужно проверить",
        traits: .sizeThatFitsLayout,
    ) {
        ScanSpeechProposalPreviewView(
            scenario: .patientName,
            layout: .card,
        )
        .dMessage()
        .dThemeWrapper()
    }

    #Preview(
        "14 Выбрано",
        traits: .sizeThatFitsLayout,
    ) {
        ScanSpeechProposalPreviewView(
            scenario: .patientName,
            layout: .card,
            isSelected: true,
        )
        .dMessage()
        .dThemeWrapper()
    }

    #Preview(
        "15 Число и единицы",
        traits: .sizeThatFitsLayout,
    ) {
        ScanSpeechProposalPreviewView(
            scenario: .measurement,
            layout: .card,
        )
        .dMessage()
        .dThemeWrapper()
    }

    #Preview(
        "16 Сторона и отрицание",
        traits: .sizeThatFitsLayout,
    ) {
        ScanSpeechProposalPreviewView(
            scenario: .clinicalText,
            layout: .card,
        )
        .dMessage()
        .dThemeWrapper()
    }

    #Preview(
        "17 Несколько полей",
    ) {
        ScanSpeechProposalPreviewView(
            scenario: .multipleFields,
            layout: .review,
        )
        .dMessage()
        .dThemeWrapper()
    }

    #Preview(
        "18 Частичный результат",
    ) {
        ScanSpeechProposalPreviewView(
            scenario: .partialResult,
            layout: .review,
        )
        .dMessage()
        .dThemeWrapper()
    }

    #Preview(
        "19 Длинный клинический текст",
    ) {
        ScanSpeechProposalPreviewView(
            scenario: .clinicalText,
            layout: .review,
        )
        .dMessage()
        .dThemeWrapper()
    }

    #Preview(
        "20 Ничего не распознано",
    ) {
        ScanSpeechProposalPreviewView(
            scenario: .empty,
            layout: .review,
        )
        .dMessage()
        .dThemeWrapper()
    }

    #Preview(
        "21 Диктовка готова",
    ) {
        ScanSpeechTranscriptPreviewView(
            scenario: .finished,
        )
        .dMessage()
        .dThemeWrapper()
    }

    #Preview(
        "22 Длинная прерванная запись",
    ) {
        ScanSpeechTranscriptPreviewView(
            scenario: .interrupted,
        )
        .dMessage()
        .dThemeWrapper()
    }

    #Preview(
        "23 Речь не распознана",
    ) {
        ScanSpeechTranscriptPreviewView(
            scenario: .failed,
        )
        .dMessage()
        .dThemeWrapper()
    }

    #Preview(
        "24 Разбор диктовки",
    ) {
        ScanSpeechTranscriptPreviewView(
            scenario: .parsing,
        )
        .dMessage()
        .dThemeWrapper()
    }
#endif
