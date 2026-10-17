import DoglyadUI
import SwiftUI

@main
struct Application: App {
    @StateObject private var viewModel = ApplicationRootViewModel()

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
