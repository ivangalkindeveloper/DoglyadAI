import DoglyadUI
import SwiftUI

struct ScanScreenView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: ScanViewModel
    @FocusState private var focus: ScanFocus?

    var body: some View {
        let speechToolbarButton: DToolbarButton? = switch viewModel.subscriptionAvailability(
            of: .formCompletionViaMicrophone,
        ) {
        case .available, .offered:
            DToolbarButton(
                accessibilityLabel: l10n[
                    .buttonSpeech,
                ],
                style: .primaryDefault,
                badge: viewModel.speechButtonBadge,
                content: .icon(
                    .microphone,
                ),
                action: viewModel.onTapSpeech,
            )
        case .unavailable: nil
        }

        let isProcessing = switch viewModel.state {
        case _ as ScanInitializingState, _ as ScanGeneratingState, _ as ScanLoadingState, _ as ScanClearingState: true
        default: false
        }
        let isMediaSelectionDisabled = switch (viewModel.state, viewModel.isPhotoLimitReached) {
        case (_ as ScanInitializingState, _), (_ as ScanGeneratingState, _), (_ as ScanLoadingState, _), (_ as ScanClearingState, _), (_, true): true
        default: false
        }

        DScreen(
            leading: {
                DButton(
                    image: .hambergerMenu,
                    action: viewModel.onTapSettings,
                )
                .dStyle(
                    .circle,
                )
                .disabled(
                    isProcessing,
                )
            },
            titleContent: {
                DButton(
                    image: .down,
                    title: viewModel.usExaminationType.localizedTitle,
                    action: viewModel.onTapUSExaminationType,
                )
                .dStyle(
                    .primaryChip,
                )
                .disabled(
                    isProcessing,
                )
                .contentTransition(
                    .opacity,
                )
            },
            onTapBody: viewModel.unfocus,
            keyboardToolbar: {
                if focus != nil {
                    DToolbar(
                        upAccessibilityLabel: l10n[
                            .buttonBack,
                        ],
                        downAccessibilityLabel: l10n[
                            .buttonNext,
                        ],
                        doneAccessibilityLabel: l10n[
                            .buttonDone,
                        ],
                        onTapUp: viewModel.isPreviousFieldFocusable ? { viewModel.onTapToolbarUp() } : nil,
                        onTapDown: viewModel.isNextFieldFocusable ? { viewModel.onTapToolbarDown() } : nil,
                        onTapDone: viewModel.unfocus,
                        trailButtons: [
                            speechToolbarButton,
                            DToolbarButton(
                                accessibilityLabel: l10n[
                                    .buttonGenerate,
                                ],
                                style: .primaryDefault,
                                content: .text(
                                    l10n[
                                        .buttonGenerate,
                                    ],
                                ),
                                action: viewModel.onTapScan,
                            ),
                        ].compactMap(
                            \.self,
                        ),
                    )
                    .disabled(
                        isProcessing,
                    )
                }
            },
            content: { toolbarHeight, _ in
                ZStack(
                    alignment: .bottom,
                ) {
                    switch viewModel.state {
                    case _ as ScanInitializationFailedState:
                        LoadingErrorView(
                            onRetry: viewModel.onTapRetryInitialization,
                        )
                    default:
                        DFocusScrollView(
                            focus: focus,
                        ) {
                            VStack(
                                alignment: .leading,
                                spacing: .zero,
                            ) {
                                switch viewModel.photos.isEmpty {
                                case true:
                                    ScanMediaButtonView(
                                        action: viewModel.onTapImport,
                                    )
                                    .disabled(
                                        isMediaSelectionDisabled,
                                    )
                                    .padding(
                                        .horizontal,
                                        size.s16,
                                    )
                                    .padding(
                                        .bottom,
                                        size.s4,
                                    )
                                    .transition(
                                        .move(
                                            edge: .top,
                                        )
                                        .combined(
                                            with: .opacity,
                                        ),
                                    )
                                case false: EmptyView()
                                }

                                ScanPhotoListView()

                                ScanFormView(
                                    focus: $focus,
                                )
                            }
                            .padding(
                                .top,
                                toolbarHeight + size.s16,
                            )
                            .padding(
                                .bottom,
                                size.s136 * 2,
                            )
                        }
                        .disabled(
                            isProcessing,
                        )
                    }
                    ScanBottomView()
                }
            },
        )
        .onSubmit {
            viewModel.onSubmit()
        }
        .onChange(
            of: focus,
            initial: true,
        ) { _, newValue in
            guard viewModel.focus != newValue else { return }
            viewModel.onFocusChanged(
                newValue,
            )
        }
        .onChange(
            of: viewModel.focus,
            initial: true,
        ) { _, newValue in
            guard focus != newValue else { return }
            focus = newValue
        }
        .onAppear {
            viewModel.onAppear()
        }
        .environmentObject(
            viewModel,
        )
    }
}
