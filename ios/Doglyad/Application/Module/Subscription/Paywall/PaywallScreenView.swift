import DoglyadUI
import SwiftUI
import UIKit

struct PaywallScreenView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: PaywallViewModel

    var body: some View {
        DScreen(
            content: { _, bottomInset in
                DScrollVStack(
                    alignment: .center,
                    spacing: .zero,
                ) {
                    DStretchyHeader(
                        height: 240,
                    ) {
                        DImage(
                            .paywallHeader,
                        )
                        .scaledToFill()
                    }
                    PaywallContentView()
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
                PaywallContinueView(
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
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.didBecomeActiveNotification,
            ),
        ) { _ in
            viewModel.onTapCheckPayment()
        }
        .onDisappear(
            perform: viewModel.onDisappear,
        )
        .environmentObject(
            viewModel,
        )
    }
}
