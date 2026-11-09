#if DEBUG
    import DoglyadUI
    import SwiftUI

    #Preview(
        "01 ApplicationRootInitialState Splash",
    ) {
        ApplicationSplashView()
            .dThemeWrapper()
    }

    #Preview(
        "02 ErrorRootOfflineErrorState Offline",
    ) {
        ApplicationSplashPreviewView(
            error: InitializationError.noInternetConnection,
        )
    }

    #Preview(
        "03 ApplicationRootLoadingState RetryingInitialization",
    ) {
        ApplicationSplashPreviewView(
            error: InitializationError.noInternetConnection,
            isRetrying: true,
        )
    }

    #Preview(
        "04 ErrorRootServiceUnavailableErrorState ServiceUnavailable",
    ) {
        ApplicationSplashPreviewView(
            error: InitializationError.serviceUnavailable(
                email: "support@doglyad.ru",
            ),
        )
    }

    #Preview(
        "05 ErrorRootUnknownErrorState InitializationFailed",
    ) {
        ApplicationSplashPreviewView(
            error: InitializationError.usExaminationTypesEmpty,
        )
    }
#endif
