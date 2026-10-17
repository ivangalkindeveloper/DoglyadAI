import DoglyadUI
import SwiftUI

struct ShareBottomSheetView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: ShareViewModel

    var body: some View {
        let isProcessing = switch viewModel.state {
        case _ as ShareSendingState: true
        default: false
        }
        let fraction: CGFloat = switch (viewModel.userEmail, viewModel.subscriptionAvailability(
            of: .sendingReportByEmail,
        )) {
        case (.some, .available), (.some, .offered): 0.4
        default: 0.3
        }

        DBottomSheet(
            title: l10n[
                .shareTitle,
            ],
            fraction: fraction,
        ) { toolbarHeight, _ in
            VStack(
                spacing: size.s8,
            ) {
                switch (viewModel.userEmail, viewModel.subscriptionAvailability(
                    of: .sendingReportByEmail,
                )) {
                case (.some, .available), (.some, .offered):
                    DButtonCard(
                        action: viewModel.onTapUserEmail,
                    ) {
                        HStack(
                            spacing: size.s8,
                        ) {
                            switch viewModel.state {
                            case _ as ShareSendingState:
                                DShimmerPlaceholder().frame(
                                    width: size.s64,
                                    height: size.s8,
                                )
                                .transition(
                                    .opacity,
                                )
                            default:
                                DIcon(
                                    .send,
                                    color: color.grayscaleHeader,
                                )
                                .transition(
                                    .opacity,
                                )
                            }
                            DText(
                                viewModel.userEmailButtonTitle,
                            )
                            .dStyle(
                                font: typography.linkSmall,
                            )
                            .lineLimit(
                                1,
                            )
                            .truncationMode(
                                .middle,
                            )
                            Spacer()
                        }
                    }
                    .disabled(
                        isProcessing,
                    )
                    .paidBadge(
                        viewModel.subscriptionAvailability(
                            of: .sendingReportByEmail,
                        ),
                    )
                    .transition(
                        .opacity,
                    )
                default: EmptyView()
                }

                switch viewModel.subscriptionAvailability(
                    of: .sendingReportByEmail,
                ) {
                case .available, .offered:
                    DButtonCard(
                        action: viewModel.onTapEmail,
                    ) {
                        ActionRowView(
                            icon: .mail,
                            title: l10n[
                                .buttonShareEmail,
                            ],
                        )
                    }
                    .disabled(
                        isProcessing,
                    )
                    .paidBadge(
                        viewModel.subscriptionAvailability(
                            of: .sendingReportByEmail,
                        ),
                    )
                    .transition(
                        .opacity,
                    )
                case .unavailable: EmptyView()
                }

                DButtonCard(
                    action: viewModel.onTapCopy,
                ) {
                    ActionRowView(
                        icon: .copy,
                        title: l10n[
                            .buttonCopy,
                        ],
                    )
                }
                .disabled(
                    isProcessing,
                )

                DShareLink(
                    item: viewModel.shareMessage,
                ) {
                    ActionRowView(
                        icon: .export,
                        title: l10n[
                            .buttonShare,
                        ],
                    )
                }
                .buttonStyle(
                    DButtonStyle(
                        .card,
                    ),
                )
                .disabled(
                    isProcessing,
                )

                Spacer()
            }
            .padding(
                .top,
                toolbarHeight + size.s16,
            )
            .padding(
                .horizontal,
                size.s16,
            )
        }
        .environmentObject(
            viewModel,
        )
        .onAppear(
            perform: viewModel.onAppear,
        )
    }
}
