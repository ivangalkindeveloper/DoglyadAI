#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 OnBoardingInitialState Welcome",
    ) {
        OnBoardingPreviewView(
            state: OnBoardingInitialState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 OnBoardingSecondState Features",
    ) {
        OnBoardingPreviewView(
            state: OnBoardingSecondState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "03 OnBoardingLegalState ConsentNotSelected",
    ) {
        OnBoardingPreviewView(
            state: OnBoardingLegalState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 OnBoardingLegalState ConsentSelected",
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
        "05 OnBoardingExaminationTypeState ChooseExaminationType",
    ) {
        OnBoardingPreviewView(
            state: OnBoardingExaminationTypeState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "06 OnBoardingFinalState ReadyToStart",
    ) {
        OnBoardingPreviewView(
            state: OnBoardingFinalState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "07 OnBoardingLoadingState SavingPreferences",
    ) {
        OnBoardingPreviewView(
            state: OnBoardingLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "08 OnBoardingErrorState PreferencesSaveFailed",
    ) {
        OnBoardingPreviewView(
            state: OnBoardingErrorState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
