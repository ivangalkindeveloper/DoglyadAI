#if DEBUG
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 ReportReceivedContentState WaitingForFirstToken",
    ) {
        ReportReceivedPreviewView(
            scenario: .waitingForFirstToken,
        )
        .previewable()
    }

    #Preview(
        "02 ReportReceivedContentState WaitingForFirstToken ScrollEnd",
    ) {
        ReportReceivedPreviewView(
            scenario: .waitingForFirstToken,
        )
        .previewable()
        .previewScrollToEnd()
    }

    #Preview(
        "03 ReportReceivedContentState FirstToken",
    ) {
        ReportReceivedPreviewView(
            scenario: .firstToken,
        )
        .previewable()
    }

    #Preview(
        "04 ReportReceivedContentState FirstToken ScrollEnd",
    ) {
        ReportReceivedPreviewView(
            scenario: .firstToken,
        )
        .previewable()
        .previewScrollToEnd()
    }

    #Preview(
        "05 ReportReceivedContentState StreamingDescription",
    ) {
        ReportReceivedPreviewView(
            scenario: .streamingDescription,
        )
        .previewable()
    }

    #Preview(
        "06 ReportReceivedContentState StreamingDescription ScrollEnd",
    ) {
        ReportReceivedPreviewView(
            scenario: .streamingDescription,
        )
        .previewable()
        .previewScrollToEnd()
    }

    #Preview(
        "07 ReportReceivedContentState StreamingConclusion",
    ) {
        ReportReceivedPreviewView(
            scenario: .streamingConclusion,
        )
        .previewable()
    }

    #Preview(
        "08 ReportReceivedContentState StreamingConclusion ScrollEnd",
    ) {
        ReportReceivedPreviewView(
            scenario: .streamingConclusion,
        )
        .previewable()
        .previewScrollToEnd()
    }

    #Preview(
        "09 ReportReceivedContentState CompletedReport",
    ) {
        ReportReceivedPreviewView(
            scenario: .completed,
        )
        .previewable()
    }

    #Preview(
        "10 ReportReceivedContentState CompletedReport ScrollEnd",
    ) {
        ReportReceivedPreviewView(
            scenario: .completed,
        )
        .previewable()
        .previewScrollToEnd()
    }

    #Preview(
        "11 ReportReceivedContentState CompletedWithRemarks",
    ) {
        ReportReceivedPreviewView(
            scenario: .completedWithRemarks,
        )
        .previewable()
    }

    #Preview(
        "12 ReportReceivedContentState CompletedWithRemarks ScrollEnd",
    ) {
        ReportReceivedPreviewView(
            scenario: .completedWithRemarks,
        )
        .previewable()
        .previewScrollToEnd()
    }

    #Preview(
        "13 ReportReceivedContentState OpenedFromReportDetail",
    ) {
        ReportReceivedPreviewView(
            scenario: .fromReportDetail,
        )
        .previewable()
    }

    #Preview(
        "14 ReportReceivedContentState OpenedFromReportDetail ScrollEnd",
    ) {
        ReportReceivedPreviewView(
            scenario: .fromReportDetail,
        )
        .previewable()
        .previewScrollToEnd()
    }

    #Preview(
        "15 ReportReceivedContentState NoWorkEmail",
    ) {
        ReportReceivedPreviewView(
            scenario: .withoutEmail,
        )
        .previewable()
    }

    #Preview(
        "16 ReportReceivedContentState NoWorkEmail ScrollEnd",
    ) {
        ReportReceivedPreviewView(
            scenario: .withoutEmail,
        )
        .previewable()
        .previewScrollToEnd()
    }

    #Preview(
        "17 ReportReceivedContentState EmailRequiresPro",
    ) {
        ReportReceivedPreviewView(
            scenario: .emailOffered,
        )
        .previewable()
    }

    #Preview(
        "18 ReportReceivedContentState EmailRequiresPro ScrollEnd",
    ) {
        ReportReceivedPreviewView(
            scenario: .emailOffered,
        )
        .previewable()
        .previewScrollToEnd()
    }

    #Preview(
        "19 ReportReceivedContentState EmailUnavailable",
    ) {
        ReportReceivedPreviewView(
            scenario: .emailUnavailable,
        )
        .previewable()
    }

    #Preview(
        "20 ReportReceivedContentState EmailUnavailable ScrollEnd",
    ) {
        ReportReceivedPreviewView(
            scenario: .emailUnavailable,
        )
        .previewable()
        .previewScrollToEnd()
    }

    #Preview(
        "21 ReportReceivedLoadingState SendingEmail",
    ) {
        ReportReceivedPreviewView(
            scenario: .sendingEmail,
        )
        .previewable()
    }

    #Preview(
        "22 ReportReceivedLoadingState SendingEmail ScrollEnd",
    ) {
        ReportReceivedPreviewView(
            scenario: .sendingEmail,
        )
        .previewable()
        .previewScrollToEnd()
    }

    #Preview(
        "23 ReportReceivedDeliveryErrorState EmailDeliveryFailed",
    ) {
        ReportReceivedPreviewView(
            scenario: .deliveryFailed,
        )
        .previewable()
    }

    #Preview(
        "24 ReportReceivedDeliveryErrorState EmailDeliveryFailed ScrollEnd",
    ) {
        ReportReceivedPreviewView(
            scenario: .deliveryFailed,
        )
        .previewable()
        .previewScrollToEnd()
    }

    #Preview(
        "25 ReportReceivedContentState InterruptedWithoutText",
    ) {
        ReportReceivedPreviewView(
            scenario: .interruptedWithoutText,
        )
        .previewable()
    }

    #Preview(
        "26 ReportReceivedContentState InterruptedWithoutText ScrollEnd",
    ) {
        ReportReceivedPreviewView(
            scenario: .interruptedWithoutText,
        )
        .previewable()
        .previewScrollToEnd()
    }

    #Preview(
        "27 ReportReceivedContentState InterruptedWithPartialText",
    ) {
        ReportReceivedPreviewView(
            scenario: .interrupted,
        )
        .previewable()
    }

    #Preview(
        "28 ReportReceivedContentState InterruptedWithPartialText ScrollEnd",
    ) {
        ReportReceivedPreviewView(
            scenario: .interrupted,
        )
        .previewable()
        .previewScrollToEnd()
    }

    #Preview(
        "29 ReportReceivedContentState GenerationFailedWithoutText",
    ) {
        ReportReceivedPreviewView(
            scenario: .failedWithoutText,
        )
        .previewable()
    }

    #Preview(
        "30 ReportReceivedContentState GenerationFailedWithoutText ScrollEnd",
    ) {
        ReportReceivedPreviewView(
            scenario: .failedWithoutText,
        )
        .previewable()
        .previewScrollToEnd()
    }

    #Preview(
        "31 ReportReceivedContentState GenerationFailedWithPartialText",
    ) {
        ReportReceivedPreviewView(
            scenario: .failed,
        )
        .previewable()
    }

    #Preview(
        "32 ReportReceivedContentState GenerationFailedWithPartialText ScrollEnd",
    ) {
        ReportReceivedPreviewView(
            scenario: .failed,
        )
        .previewable()
        .previewScrollToEnd()
    }

    #Preview(
        "33 ReportReceivedContentState GenerationCancelled",
    ) {
        ReportReceivedPreviewView(
            scenario: .cancelled,
        )
        .previewable()
    }

    #Preview(
        "34 ReportReceivedContentState GenerationCancelled ScrollEnd",
    ) {
        ReportReceivedPreviewView(
            scenario: .cancelled,
        )
        .previewable()
        .previewScrollToEnd()
    }
#endif
