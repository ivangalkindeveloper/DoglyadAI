import DependencyInitializer
import SwiftUI

@MainActor
final class ApplicationViewModel: DViewModel {
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
                createProcess: { InitializationProcess() },
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
                onError: { [weak self] error, _, _, _ in
                    guard let self = self else { return }

                    self.isLoading = false
                    self.root = ErrorRootView(
                        error: error
                    )
                    self.rootID = UUID()
                }
            ).run()
        }
    }

    func openSettings() {
        UIApplication.openSettings()
    }
}
