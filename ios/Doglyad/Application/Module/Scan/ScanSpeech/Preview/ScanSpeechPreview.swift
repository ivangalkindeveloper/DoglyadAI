#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 ScanSpeechModelLoadingState CheckingModel",
    ) {
        ScanSpeechPreviewView(
            state: ScanSpeechModelLoadingState(
                preparation: .checking,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 ScanSpeechModelLoadingState DownloadingWithoutProgress",
    ) {
        ScanSpeechPreviewView(
            state: ScanSpeechModelLoadingState(
                preparation: .downloading(
                    progress: nil,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "03 ScanSpeechModelLoadingState DownloadingWithProgress",
    ) {
        ScanSpeechPreviewView(
            state: ScanSpeechModelLoadingState(
                preparation: .downloading(
                    progress: 0.45,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 ScanSpeechModelLoadingState LoadingModelIntoMemory",
    ) {
        ScanSpeechPreviewView(
            state: ScanSpeechModelLoadingState(
                preparation: .loading,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "05 ScanSpeechModelPreparationErrorState ModelPreparationFailed",
    ) {
        ScanSpeechPreviewView(
            state: ScanSpeechModelPreparationErrorState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "06 ScanSpeechReadyState ReadyToRecord",
    ) {
        ScanSpeechPreviewView(
            state: ScanSpeechReadyState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "07 ScanSpeechRecordingPreparationLoadingState PreparingRecording",
    ) {
        ScanSpeechPreviewView(
            state: ScanSpeechRecordingPreparationLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "08 ScanSpeechRecordingState RecordingSpeech",
    ) {
        ScanSpeechPreviewView(
            state: ScanSpeechRecordingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "09 ScanSpeechTranscriptionLoadingState TranscribingSpeech",
    ) {
        ScanSpeechPreviewView(
            state: ScanSpeechTranscriptionLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "10 ScanSpeechReviewTranscriptState TranscriptReview",
    ) {
        ScanSpeechPreviewView(
            state: ScanSpeechReviewTranscriptState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "11 ScanSpeechReviewTranscriptState TranscriptReview ScrollEnd",
    ) {
        ScanSpeechPreviewView(
            state: ScanSpeechReviewTranscriptState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "12 ScanSpeechReviewParsingLoadingState ParsingReviewedTranscript",
    ) {
        ScanSpeechPreviewView(
            state: ScanSpeechReviewParsingLoadingState(
                parsedText: USExaminationReportPreviewFactory.description,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "13 ScanSpeechReviewParsingLoadingState ParsingReviewedTranscript ScrollEnd",
    ) {
        ScanSpeechPreviewView(
            state: ScanSpeechReviewParsingLoadingState(
                parsedText: USExaminationReportPreviewFactory.description,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "14 ScanSpeechReviewProposalState MultipleFields",
    ) {
        ScanSpeechPreviewView(
            state: ScanSpeechProposalPreviewFixture(
                scenario: .multipleFields,
            ).state,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "15 ScanSpeechReviewProposalState MultipleFields ScrollEnd",
    ) {
        ScanSpeechPreviewView(
            state: ScanSpeechProposalPreviewFixture(
                scenario: .multipleFields,
            ).state,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "16 ScanSpeechProposalPreviewView ReviewRequired",
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
        "17 ScanSpeechProposalPreviewView SelectedProposal",
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
        "18 ScanSpeechProposalPreviewView MeasurementAndUnit",
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
        "19 ScanSpeechProposalPreviewView SideAndNegation",
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
        "20 ScanSpeechProposalPreviewView MultipleFields",
    ) {
        ScanSpeechProposalPreviewView(
            scenario: .multipleFields,
            layout: .review,
        )
        .dMessage()
        .dThemeWrapper()
    }

    #Preview(
        "21 ScanSpeechProposalPreviewView PartialResult",
    ) {
        ScanSpeechProposalPreviewView(
            scenario: .partialResult,
            layout: .review,
        )
        .dMessage()
        .dThemeWrapper()
    }

    #Preview(
        "22 ScanSpeechProposalPreviewView LongClinicalText",
    ) {
        ScanSpeechProposalPreviewView(
            scenario: .clinicalText,
            layout: .review,
        )
        .dMessage()
        .dThemeWrapper()
    }

    #Preview(
        "23 ScanSpeechProposalPreviewView NoRecognizedFields",
    ) {
        ScanSpeechProposalPreviewView(
            scenario: .empty,
            layout: .review,
        )
        .dMessage()
        .dThemeWrapper()
    }

    #Preview(
        "24 ScanSpeechTranscriptPreviewView FinishedDictation",
    ) {
        ScanSpeechTranscriptPreviewView(
            scenario: .finished,
        )
        .dMessage()
        .dThemeWrapper()
    }

    #Preview(
        "25 ScanSpeechTranscriptPreviewView InterruptedLongDictation",
    ) {
        ScanSpeechTranscriptPreviewView(
            scenario: .interrupted,
        )
        .dMessage()
        .dThemeWrapper()
    }

    #Preview(
        "26 ScanSpeechTranscriptPreviewView NoRecognizedSpeech",
    ) {
        ScanSpeechTranscriptPreviewView(
            scenario: .failed,
        )
        .dMessage()
        .dThemeWrapper()
    }

    #Preview(
        "27 ScanSpeechTranscriptPreviewView ParsingDictation",
    ) {
        ScanSpeechTranscriptPreviewView(
            scenario: .parsing,
        )
        .dMessage()
        .dThemeWrapper()
    }
#endif
