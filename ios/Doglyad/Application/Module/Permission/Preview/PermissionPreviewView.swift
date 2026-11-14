#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct PermissionPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let state: any PermissionStateProtocol
        let kind: PermissionArguments.Kind

        init(
            state: any PermissionStateProtocol,
            kind: PermissionArguments.Kind,
        ) {
            self.state = state
            self.kind = kind
        }

        var body: some View {
            let model = PermissionViewModel(
                container: container,
                router: router,
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
                arguments: PermissionArguments(
                    kind: kind,
                ),
            )

            model.preparePreview(
                state: state,
            )
            return ModuleBottomSheetPreviewView {
                PermissionBottomSheetView(
                    viewModel: model,
                )
            }
            .id(
                ObjectIdentifier(
                    state,
                ),
            )
        }
    }
#endif
