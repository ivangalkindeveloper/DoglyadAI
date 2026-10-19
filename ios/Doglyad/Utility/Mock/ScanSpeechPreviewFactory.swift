#if DEBUG
    import Combine
    import DoglyadSpeech
    import DoglyadUI
    import Foundation

    @MainActor
    enum ScanSpeechPreviewFactory {
        static func makeContainer() -> DependencyContainer {
            DependencyContainer.makePreviewable(
                l10n: L10NPreviewFactory.make(),
            )
        }

        static func makeViewModel(
            container: DependencyContainer,
            messager: DMessager,
            router: DRouter,
            speechController: (any DSpeechControllerProtocol)? = nil,
        ) -> ScanSpeechViewModel {
            ScanSpeechViewModel(
                container: container,
                messager: messager,
                router: router,
                getSubscriptionStatus: { nil },
                observeSubscriptionStatus: { _ in AnyCancellable {} },
                onSubscriptionStatusUpdated: { _ in },
                getSettingsAI: { container.initialSettingsAI },
                onRequestCountIncremented: {},
                arguments: ScanSpeechArguments(
                    examinationType: container.usExaminationTypeDefault,
                    onConfirm: { _ in true },
                ),
                speechController: speechController,
            )
        }
    }
#endif
