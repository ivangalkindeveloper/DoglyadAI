import DoglyadUI
import SwiftUI

struct ShareBottomSheetView: DView {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: ShareViewModel

    var body: some View {
        DBottomSheet(
            title: l10n[
                .shareTitle,
            ],
            fraction: viewModel.isUserEmailAvailable && viewModel.isUserEmailButtonVisible ? 0.4 : 0.3,
        ) { toolbarHeight, _ in
            VStack(
                spacing: size.s8,
            ) {
                if viewModel.isUserEmailAvailable, viewModel.isUserEmailButtonVisible {
                    DButtonCard(
                        action: viewModel.onTapUserEmail,
                    ) {
                        HStack(
                            spacing: size.s8,
                        ) {
                            if viewModel.isLoading {
                                DShimmerPlaceholder().frame(
                                    width: size.s64,
                                    height: size.s8,
                                )
                                .transition(
                                    .opacity,
                                )
                            } else {
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
                        viewModel.isLoading,
                    )
                    .paidBadge(
                        viewModel.subscriptionAvailability(
                            of: .sendingReportByEmail,
                        ),
                    )
                    .transition(
                        .opacity,
                    )
                }

                if viewModel.isUserEmailButtonVisible {
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
                        viewModel.isLoading,
                    )
                    .paidBadge(
                        viewModel.subscriptionAvailability(
                            of: .sendingReportByEmail,
                        ),
                    )
                    .transition(
                        .opacity,
                    )
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
                    viewModel.isLoading,
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
                    viewModel.isLoading,
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
        .animation(
            theme.animation,
            value: viewModel.isLoading,
        )
        .animation(
            theme.animation,
            value: viewModel.isUserEmailButtonVisible,
        )
        .environmentObject(
            viewModel,
        )
        .onAppear(
            perform: viewModel.onAppear,
        )
    }
}
