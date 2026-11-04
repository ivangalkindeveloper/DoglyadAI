import DoglyadUI
import SwiftUI

#if !DOGLYAD_REGRESSION
    @main
#endif
struct Application: App {
    @StateObject private var viewModel = ApplicationRootViewModel()

    var body: some Scene {
        WindowGroup {
            ApplicationRootView()
                .onAppear {
                    viewModel.initialize()
                }
                .onOpenURL { url in
                    viewModel.onOpenURL(
                        url,
                    )
                }
                .dThemeWrapper()
                .environmentObject(
                    viewModel,
                )
        }
    }
}
