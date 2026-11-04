#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "OnBoardingCompletingState",
    ) {
        OnBoardingPreviewView(
            state: OnBoardingCompletingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "OnBoardingExaminationTypeState",
    ) {
        OnBoardingPreviewView(
            state: OnBoardingExaminationTypeState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "OnBoardingFailedState",
    ) {
        OnBoardingPreviewView(
            state: OnBoardingFailedState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "OnBoardingFinalState",
    ) {
        OnBoardingPreviewView(
            state: OnBoardingFinalState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "OnBoardingFirstState",
    ) {
        OnBoardingPreviewView(
            state: OnBoardingFirstState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "OnBoardingLegalState",
    ) {
        OnBoardingPreviewView(
            state: OnBoardingLegalState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "OnBoardingSecondState",
    ) {
        OnBoardingPreviewView(
            state: OnBoardingSecondState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "Согласие принято",
    ) {
        OnBoardingPreviewView(
            state: OnBoardingLegalState(
                isLegalAccepted: true,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
