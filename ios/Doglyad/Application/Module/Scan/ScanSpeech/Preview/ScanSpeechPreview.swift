#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "ScanSpeechAutomaticParsingState",
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
        "ScanSpeechModelPreparationFailedState",
    ) {
        ScanSpeechPreviewView(
            state: ScanSpeechModelPreparationFailedState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "ScanSpeechPreparingModelState",
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
        "ScanSpeechPreparingRecordingState",
    ) {
        ScanSpeechPreviewView(
            state: ScanSpeechPreparingRecordingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "ScanSpeechReadyState",
    ) {
        ScanSpeechPreviewView(
            state: ScanSpeechReadyState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "ScanSpeechRecordingState",
    ) {
        ScanSpeechPreviewView(
            state: ScanSpeechRecordingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "ScanSpeechReviewParsingState",
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
        "ScanSpeechReviewTranscriptState",
    ) {
        ScanSpeechPreviewView(
            state: ScanSpeechReviewTranscriptState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "ScanSpeechTranscribingState",
    ) {
        ScanSpeechPreviewView(
            state: ScanSpeechTranscribingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "Проверка модели",
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
        "Загрузка без прогресса",
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
        "Загрузка модели в память",
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
        "Нужно проверить",
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
        "Выбрано",
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
        "Число и единицы",
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
        "Сторона и отрицание",
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
        "Несколько полей",
    ) {
        ScanSpeechProposalPreviewView(
            scenario: .multipleFields,
            layout: .review,
        )
        .dMessage()
        .dThemeWrapper()
    }

    #Preview(
        "Частичный результат",
    ) {
        ScanSpeechProposalPreviewView(
            scenario: .partialResult,
            layout: .review,
        )
        .dMessage()
        .dThemeWrapper()
    }

    #Preview(
        "Длинный клинический текст",
    ) {
        ScanSpeechProposalPreviewView(
            scenario: .clinicalText,
            layout: .review,
        )
        .dMessage()
        .dThemeWrapper()
    }

    #Preview(
        "Ничего не распознано",
    ) {
        ScanSpeechProposalPreviewView(
            scenario: .empty,
            layout: .review,
        )
        .dMessage()
        .dThemeWrapper()
    }

    #Preview(
        "Диктовка готова",
    ) {
        ScanSpeechTranscriptPreviewView(
            scenario: .finished,
        )
        .dMessage()
        .dThemeWrapper()
    }

    #Preview(
        "Длинная прерванная запись",
    ) {
        ScanSpeechTranscriptPreviewView(
            scenario: .interrupted,
        )
        .dMessage()
        .dThemeWrapper()
    }

    #Preview(
        "Речь не распознана",
    ) {
        ScanSpeechTranscriptPreviewView(
            scenario: .failed,
        )
        .dMessage()
        .dThemeWrapper()
    }

    #Preview(
        "Разбор диктовки",
    ) {
        ScanSpeechTranscriptPreviewView(
            scenario: .parsing,
        )
        .dMessage()
        .dThemeWrapper()
    }
#endif
