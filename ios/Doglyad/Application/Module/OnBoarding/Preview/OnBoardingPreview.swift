#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 OnBoardingFirstState",
    ) {
        OnBoardingPreviewView(
            state: OnBoardingFirstState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 OnBoardingSecondState",
    ) {
        OnBoardingPreviewView(
            state: OnBoardingSecondState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "03 OnBoardingLegalState",
    ) {
        OnBoardingPreviewView(
            state: OnBoardingLegalState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 Согласие принято",
    ) {
        OnBoardingPreviewView(
            state: OnBoardingLegalState(
                isLegalAccepted: true,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "05 OnBoardingExaminationTypeState",
    ) {
        OnBoardingPreviewView(
            state: OnBoardingExaminationTypeState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "06 OnBoardingFinalState",
    ) {
        OnBoardingPreviewView(
            state: OnBoardingFinalState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "07 OnBoardingCompletingState",
    ) {
        OnBoardingPreviewView(
            state: OnBoardingCompletingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "08 OnBoardingFailedState",
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
#endif
