import DoglyadUI
import SwiftUI

struct ReportReceivedBottomSheetView: DView {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: ReportReceivedViewModel

    var body: some View {
        DBottomSheet(
            type: .blur,
            title: l10n[
                .reportTitle,
            ],
            fraction: 1,
            content: { toolbarHeight, bottomHeight in
                VStack(
                    spacing: .zero,
                ) {
                    ScrollView {
                        ReportReceivedMarkdownView(
                            textColor: color.grayscaleBackgroundWeak,
                        )
                        .environmentObject(
                            viewModel.markdownViewModel,
                        )
                        .padding(
                            .top,
                            toolbarHeight,
                        )
                        .padding(
                            size.s16,
                        )
                        .padding(
                            .bottom,
                            bottomHeight,
                        )
                    }
                    .mask(
                        VStack(
                            spacing: .zero,
                        ) {
                            LinearGradient(
                                colors: [.clear, .black],
                                startPoint: .top,
                                endPoint: .bottom,
                            )
                            .frame(
                                height: size.s16,
                            )

                            Color.black
                        },
                    )
                }
            },
            bottom: {
                VStack(
                    spacing: size.s8,
                ) {
                    DButton(
                        title: l10n[
                            .buttonToReport,
                        ],
                        action: viewModel.onTapReport,
                    )
                    .dStyle(
                        .primaryButton,
                    )

                    if viewModel.isUserEmailAvailable, viewModel.isUserEmailButtonVisible {
                        DButton(
                            image: .send,
                            title: viewModel.userEmailButtonTitle,
                            badge: viewModel.userEmailButtonBadge,
                            action: viewModel.onTapUserEmail,
                            isLoading: viewModel.isLoading,
                        )
                        .dStyle(
                            .textWeak,
                        )
                        .transition(
                            .opacity,
                        )
                    }

                    DButton(
                        image: .copy,
                        title: l10n[
                            .buttonCopy,
                        ],
                        action: viewModel.onTapCopy,
                    )
                    .dStyle(
                        .textWeak,
                    )
                    .padding(
                        .bottom,
                        size.s10,
                    )
                }
                .padding(
                    .top,
                    size.s8,
                )
                .padding(
                    .horizontal,
                    size.s16,
                )
            },
        )
        .animation(
            theme.animation,
            value: viewModel.isUserEmailButtonVisible,
        )
        .onAppear {
            viewModel.onAppear()
        }
    }
}
