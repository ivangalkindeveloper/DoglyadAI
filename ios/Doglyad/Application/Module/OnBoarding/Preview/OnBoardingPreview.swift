#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 OnBoardingInitialState",
    ) {
        OnBoardingPreviewView(
            state: OnBoardingInitialState(),
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
        "07 OnBoardingLoadingState",
    ) {
        OnBoardingPreviewView(
            state: OnBoardingLoadingState(),
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
