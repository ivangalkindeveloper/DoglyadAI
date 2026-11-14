import DoglyadUI
import SwiftUI

#if !DOGLYAD_REGRESSION
    @main
#endif
struct Application: App {
    @StateObject private var viewModel = ApplicationRootViewModel()

    init() {}

    var body: some Scene {
        WindowGroup {
            ApplicationRootView()
                .onAppear {
                    viewModel.initialize()
                }
                .dThemeWrapper()
                .environmentObject(
                    viewModel,
                )
        }
    }
}
