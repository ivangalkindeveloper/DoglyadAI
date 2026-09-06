import DependencyInitializer
import SwiftUI

@MainActor
final class ApplicationViewModel: ObservableObject {
    @Published var root: any View = Color.white
        .overlay {
            Image(.splash)
                .resizable()
                .scaledToFill()
        }
        .ignoresSafeArea()
    @Published var rootID = UUID()
    @Published var isLoading = false
    private var isFirebaseConfigured = false

    @MainActor
    func initialize() {
        isLoading = true
        Task {
            await DependencyInitializer<InitializationProcess, DependencyContainer>(
                createProcess: InitializationProcess.init,
                stepSets: [
                    InitializationProcess.stepsTier1(
                        getIsFirebaseConfigured: { [weak self] in
                            self?.isFirebaseConfigured ?? false
                        },
                        onFirebaseConfigured: { [weak self] in
                            self?.isFirebaseConfigured = true
                        }
                    ),
                    InitializationProcess.stepsTier2,
                    InitializationProcess.stepsTier3,
                    InitializationProcess.stepsTier4,
                    InitializationProcess.stepsTier5,
                ],
                onSuccess: { [weak self] result, _ in
                    guard let self = self else { return }

                    self.isLoading = false
                    self.root = MainRootView(
                        dependencyContainer: result.container
                    )
                    self.rootID = UUID()
                },
                onError: { [weak self] error, process, _, _ in
                    guard let self = self else { return }

                    self.isLoading = false
                    self.root = ErrorRootView(
                        error: error,
                        analytics: process.analytics
                    )
                    self.rootID = UUID()
                }
            ).run()
        }
    }

    func retryInitialization() {
        initialize()
    }

    func openSettings() {
        UIApplication.openSettings()
    }
}
