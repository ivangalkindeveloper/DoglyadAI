import DoglyadUI
import SwiftData
import SwiftUI

@main
struct Application: App {
    @StateObject private var viewModel = ApplicationViewModel()

    var body: some Scene {
        WindowGroup {
            ZStack {
                AnyView(
                    viewModel.root,
                )
                .id(
                    viewModel.rootID,
                )
                .transition(
                    .asymmetric(
                        insertion: .opacity,
                        removal: .opacity,
                    ),
                )
            }
            .animation(
                .easeInOut(
                    duration: 0.35,
                ),
                value: viewModel.rootID,
            )
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
