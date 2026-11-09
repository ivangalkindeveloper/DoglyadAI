#if DEBUG
    import DoglyadUI
    import SwiftUI

    struct ApplicationSplashPreviewView: View {
        let error: Error
        var isRetrying = false

        var body: some View {
            let model = ApplicationRootViewModel()
            let failure = ApplicationRootErrorState(
                error: error,
            )
            if isRetrying {
                model.emit(
                    ApplicationRootLoadingState(
                        previousFailure: failure,
                    ),
                )
            } else {
                model.emit(
                    failure,
                )
            }
            return ErrorRootView(
                error: error,
                analytics: nil,
            )
            .environmentObject(
                model,
            )
            .environment(
                \.locale,
                Locale(
                    identifier: "ru",
                ),
            )
            .dThemeWrapper()
            .allowsHitTesting(
                false,
            )
        }
    }
#endif
