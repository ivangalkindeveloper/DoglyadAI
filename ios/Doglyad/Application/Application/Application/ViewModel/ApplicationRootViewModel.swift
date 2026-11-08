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
        case _ as ApplicationRootLoadingState: return
        default: break
        }
        let previousFailure: ApplicationRootFailedState? = switch state {
        case let state as ApplicationRootFailedState: state
        default: nil
        }
        emit(
            ApplicationRootLoadingState(
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
                    InitializationProcess.stepsLocalBillingReset(),
                    InitializationProcess.stepsTier2,
                    InitializationProcess.stepsTier3,
                    InitializationProcess.stepsTier4,
                    InitializationProcess.stepsTier5,
                ],
                onSuccess: { [weak self] result, _ in
                    guard let self else {
                        return
                    }

                    analytics = result.container.analytics
                    emit(
                        ApplicationRootSuccessState(
                            container: result.container,
                        ),
                    )
                },
                onError: { [weak self] error, process, step, _ in
                    guard let self else {
                        return
                    }

                    InitializationLogger.logFailure(
                        step: step.title,
                        error: error,
                    )
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

    func onOpenURL(
        _ url: URL,
    ) {
        YooKassaPaymentController.handleOpen(
            url: url,
        )
    }

    func retryInitialization() {
        initialize()
    }
}
