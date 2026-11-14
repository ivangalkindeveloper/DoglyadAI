#if DEBUG && DOGLYAD_REGRESSION
    import DoglyadUI
    import SwiftUI

    @main
    struct RegressionApplication: App {
        init() {}

        var body: some Scene {
            WindowGroup {
                if let identity = UserDefaults.standard.string(
                    forKey: "regressionPreview",
                ), !identity.isEmpty {
                    RegressionScreens(
                        identity: identity,
                    )
                } else {
                    RegressionLiveApplicationView()
                }
            }
        }
    }

    struct RegressionLiveApplicationView: View {
        @StateObject private var viewModel = ApplicationRootViewModel()
        @State private var waitingForSplashCapture = UserDefaults.standard.bool(
            forKey: "regressionCaptureSplash",
        )

        init() {}

        var body: some View {
            ApplicationRootView()
                .gesture(
                    TapGesture().onEnded {
                        if waitingForSplashCapture {
                            waitingForSplashCapture = false
                            viewModel.initialize()
                        }
                    },
                    including: waitingForSplashCapture ? .all : .subviews,
                )
                .onAppear {
                    if !waitingForSplashCapture {
                        viewModel.initialize()
                    }
                }
                .dThemeWrapper()
                .environmentObject(
                    viewModel,
                )
        }
    }
#endif
