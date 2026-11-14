import DoglyadUI
import SwiftUI
import UIKit

struct SubscriptionManageScreenView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @StateObject var viewModel: SubscriptionManageViewModel

    init(
        viewModel: @autoclosure @escaping () -> SubscriptionManageViewModel,
    ) {
        _viewModel = StateObject(
            wrappedValue: viewModel(),
        )
    }

    var body: some View {
        DScreen(
            title: l10n[
                .subscriptionManageTitle,
            ],
            onTapBack: viewModel.onTapBack,
            content: { toolbarInset, bottomInset in
                switch viewModel.state {
                case let failed as SubscriptionManageErrorState:
                    ErrorBodyView(
                        description: failed.errorDescription,
                    )
                    .padding(
                        size.s16,
                    )
                    .padding(
                        .top,
                        toolbarInset,
                    )
                    .padding(
                        .bottom,
                        bottomInset,
                    )
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                    )
                default:
                    DScrollVStack(
                        spacing: size.s8,
                        padding: EdgeInsets(
                            top: toolbarInset + size.s16,
                            leading: size.s16,
                            bottom: bottomInset + size.s32,
                            trailing: size.s16,
                        ),
                    ) {
                        SubscriptionManageStateView(
                            state: viewModel.state,
                        )
                    }
                }
            },
            bottom: {
                SubscriptionManageBottomView()
            },
        )
        .environmentObject(
            viewModel,
        )
        .onAppear(
            perform: viewModel.onAppear,
        )
        .onDisappear(
            perform: viewModel.onDisappear,
        )
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.didBecomeActiveNotification,
            ),
        ) { _ in
            viewModel.onRefresh()
        }
    }
}
