import DoglyadUI
import SwiftUI

struct SubscriptionScreenView: DView {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: SubscriptionScreenViewModel

    var body: some View {
        DScreen(
            title: l10n[
                .subscriptionTitle,
            ],
            onTapBack: viewModel.onTapBack,
        ) { toolbarInset, _ in
            ScrollView(
                showsIndicators: false,
            ) {
                VStack(
                    spacing: size.s8,
                ) {
                    DListButtonCard(
                        title: l10n[
                            .subscriptionChangeTypeTitle,
                        ],
                        description: l10n[
                            .subscriptionChangeTypeDescription,
                        ],
                        action: viewModel.onTapChangeType,
                    )
                    DListButtonCard(
                        title: l10n[
                            .subscriptionSupportCenterTitle,
                        ],
                        description: l10n[
                            .subscriptionSupportCenterDescription,
                        ],
                        action: viewModel.onTapSupportCenter,
                    )
                }
                .padding(
                    size.s16,
                )
                .padding(
                    .top,
                    toolbarInset,
                )
                .padding(
                    .bottom,
                    size.s32,
                )
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
        .environmentObject(
            viewModel,
        )
    }
}
