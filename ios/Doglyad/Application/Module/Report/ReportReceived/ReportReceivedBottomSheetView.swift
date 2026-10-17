import DoglyadUI
import SwiftUI

struct ReportReceivedBottomSheetView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: ReportReceivedViewModel

    var body: some View {
        let isSending = switch viewModel.state {
        case _ as ReportReceivedSendingState: true
        default: false
        }

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
                            .reportReceivedOpenReportButton,
                        ],
                        action: viewModel.onTapReport,
                    )
                    .dStyle(
                        .primaryButton,
                    )

                    switch (viewModel.userEmail, viewModel.subscriptionAvailability(
                        of: .sendingReportByEmail,
                    )) {
                    case (.some, .available), (.some, .offered):
                        DButton(
                            image: .send,
                            title: viewModel.userEmailButtonTitle,
                            truncatingTitleSuffix: viewModel.userEmail,
                            badge: viewModel.userEmailButtonBadge,
                            action: viewModel.onTapUserEmail,
                            isLoading: isSending,
                        )
                        .dStyle(
                            .textWeak,
                        )
                        .transition(
                            .opacity,
                        )
                    default: EmptyView()
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
        .environmentObject(
            viewModel,
        )
        .onAppear {
            viewModel.onAppear()
        }
    }
}
