#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct SharePreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        @EnvironmentObject private var messager: DMessager
        let state: any ShareStateProtocol

        var body: some View {
            let isErrorPresented = switch state {
            case _ as ShareFailedState: true
            default: false
            }

            let model = ShareViewModel(
                container: container,
                messager: messager,
                router: router,
                arguments: ShareArguments(
                    report: ModulePreviewFactory.report,
                ),
                getSubscriptionStatus: {
                    ModulePreviewFactory.subscription
                },
                observeSubscriptionStatus: { _ in
                    AnyCancellable {}
                },
                onSubscriptionStatusUpdated: { _ in },
                getSettingsAI: {
                    container.initialSettingsAI
                },
                onRefreshSubscriptionStatus: {},
                getUserEmail: {
                    "doctor@example.com"
                },
            )

            model.preparePreview(
                state: state,
            )
            return ModuleBottomSheetPreviewView {
                ShareBottomSheetView(
                    viewModel: model,
                )
            }
            .previewError(
                isPresented: isErrorPresented,
            )
            .id(
                ObjectIdentifier(
                    state,
                ),
            )
        }
    }
#endif
