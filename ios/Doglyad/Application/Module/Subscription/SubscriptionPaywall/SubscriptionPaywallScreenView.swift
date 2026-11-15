import DoglyadUI
import SwiftUI
import UIKit

struct SubscriptionPaywallScreenView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: SubscriptionPaywallViewModel

    init(
        viewModel: @autoclosure @escaping () -> SubscriptionPaywallViewModel,
    ) {
        _viewModel = StateObject(
            wrappedValue: viewModel(),
        )
    }

    var body: some View {
        DScreen(
            content: { _, bottomInset in
                Group {
                    switch viewModel.state {
                    case let failed as SubscriptionPaywallCatalogErrorState:
                        SubscriptionPaywallLoadingErrorView(
                            state: failed,
                        )
                        .padding(
                            .horizontal,
                            size.s16,
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
                            alignment: .center,
                            spacing: .zero,
                        ) {
                            DStretchyHeader(
                                height: 240,
                            ) {
                                Image(
                                    .paywallHeader,
                                )
                                .resizable()
                                .scaledToFill()
                            }
                            SubscriptionPaywallContentView()
                                .padding(
                                    .horizontal,
                                    size.s16,
                                )
                                .padding(
                                    .bottom,
                                    bottomInset + size.s32,
                                )
                        }
                        .scrollBounceBehavior(
                            .always,
                            axes: .vertical,
                        )
                        .ignoresSafeArea(
                            .container,
                            edges: .top,
                        )
                    }
                }
                .overlay(
                    alignment: .topLeading,
                ) {
                    if viewModel.isDismissible {
                        DButton(
                            image: .back,
                            action: viewModel.onTapClose,
                        )
                        .dStyle(
                            .circle,
                        )
                        .padding(
                            size.s8,
                        )
                    }
                }
            },
            bottom: {
                SubscriptionPaywallContinueView(
                    state: viewModel.state,
                )
                .padding(
                    size.s16,
                )
            },
        )
        .onAppear(
            perform: viewModel.onAppear,
        )
        .onDisappear(
            perform: viewModel.onDisappear,
        )
        .environmentObject(
            viewModel,
        )
    }
}
