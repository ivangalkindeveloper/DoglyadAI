import DependencyInitializer
import DoglyadUI
import SwiftUI

@MainActor
final class ApplicationRootViewModel: DStateViewModel<any ApplicationRootStateProtocol> {
    private(set) var analytics: AnalyticsManager?
    private var isFirebaseConfigured = false

    init() {
        super.init(
            state: ApplicationRootInitialState(),
        )
    }

    @MainActor
    func initialize() {
        switch state {
        case _ as ApplicationRootInitializingState: return
        default: break
        }
        let previousFailure: ApplicationRootFailedState? = switch state {
        case let state as ApplicationRootFailedState: state
        default: nil
        }
        emit(
            ApplicationRootInitializingState(
                previousFailure: previousFailure,
            ),
        )
        Task { [self] in
            await DependencyInitializer<InitializationProcess, DependencyContainer>(
                createProcess: InitializationProcess.init,
                stepSets: [
                    InitializationProcess.stepsTier1(
                        getIsFirebaseConfigured: { [weak self] in
                            self?.isFirebaseConfigured ?? false
                        },
                        onFirebaseConfigured: { [weak self] in
                            self?.isFirebaseConfigured = true
                        },
                    ),
                    InitializationProcess.stepsTier2,
                    InitializationProcess.stepsTier3,
                    InitializationProcess.stepsTier4,
                    InitializationProcess.stepsTier5,
                ],
                onSuccess: { [weak self] result, _ in
                    guard let self else { return }

                    analytics = result.container.analytics
                    emit(
                        ApplicationRootReadyState(
                            container: result.container,
                        ),
                    )
                },
                onError: { [weak self] error, process, _, _ in
                    guard let self else { return }

                    analytics = process.analytics
                    emit(
                        ApplicationRootFailedState(
                            error: error,
                        ),
                    )
                },
            ).run()
        }
    }

    func retryInitialization() {
        initialize()
    }
}
