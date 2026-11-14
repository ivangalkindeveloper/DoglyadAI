import DoglyadUI
import SwiftUI

struct ReportReceivedBottomSheetView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: ReportReceivedViewModel
    @State private var generationFailureCardHeight: CGFloat = 0

    init(
        viewModel: @autoclosure @escaping () -> ReportReceivedViewModel,
    ) {
        _viewModel = StateObject(
            wrappedValue: viewModel(),
        )
    }

    var body: some View {
        let isSending = switch viewModel.state {
        case _ as ReportReceivedLoadingState: true
        default: false
        }

        DBottomSheet(
            type: .blur,
            title: l10n[
                .reportTitle,
            ],
            fraction: 1,
            content: { toolbarHeight, bottomHeight in
                ZStack(
                    alignment: .bottom,
                ) {
                    DScrollVStack(
                        padding: EdgeInsets(
                            top: toolbarHeight + size.s16,
                            leading: size.s16,
                            bottom: bottomHeight + size.s16 + (viewModel.generationFailureTitle == nil ? 0 : generationFailureCardHeight + size.s8),
                            trailing: size.s16,
                        ),
                    ) {
                        ReportReceivedMarkdownView()
                    }
                    .transaction { transaction in
                        // Stream updates resize text immediately; controls animate outside this subtree.
                        transaction.animation = nil
                    }
                    if let title = viewModel.generationFailureTitle {
                        DMessageCard(
                            type: .error,
                            title: l10n[
                                title,
                            ],
                            alignment: .center,
                        )
                        .onGeometryChange(
                            for: CGFloat.self,
                            of: {
                                $0.size.height
                            },
                        ) { height in
                            generationFailureCardHeight = height
                        }
                        .padding(
                            .horizontal,
                            size.s16,
                        )
                        .padding(
                            .bottom,
                            bottomHeight + size.s8,
                        )
                        .transition(
                            .move(
                                edge: .bottom,
                            ).combined(
                                with: .opacity,
                            ),
                        )
                    }
                }
            },
            bottom: {
                if viewModel.canRetry || viewModel.isCompleted {
                    VStack(
                        spacing: size.s8,
                    ) {
                        if viewModel.canRetry {
                            DButton(
                                image: .refresh,
                                title: l10n[
                                    .reportGenerationRetryButton,
                                ],
                                action: viewModel.onTapRetryGeneration,
                                accessibilityIdentifier: "reportReceived.retryGeneration",
                            ).dStyle(
                                .primaryButton,
                            )
                        }
                        if viewModel.isCompleted {
                            if viewModel.isReportNavigationAvailable {
                                DButton(
                                    title: l10n[
                                        .reportReceivedOpenReportButton,
                                    ],
                                    action: viewModel.onTapReport,
                                    isDisabled: isSending,
                                    accessibilityIdentifier: "reportReceived.openReport",
                                )
                                .dStyle(
                                    .primaryButton,
                                )
                            }

                            ReportReceivedEmailButtonView()

                            DButton(
                                image: .copy,
                                title: l10n[
                                    .buttonCopy,
                                ],
                                action: viewModel.onTapCopy,
                                isDisabled: isSending,
                                accessibilityIdentifier: "reportReceived.copy",
                            )
                            .dStyle(
                                .textWeak,
                            )
                            .padding(
                                .bottom,
                                size.s10,
                            )
                        }
                    }
                    .padding(
                        .top,
                        size.s8,
                    )
                    .padding(
                        .horizontal,
                        size.s16,
                    )
                }
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
