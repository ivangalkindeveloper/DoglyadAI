import DoglyadUI
import SwiftUI

struct ScanScreenView: DView {
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: ScanViewModel
    @FocusState private var focus: ScanViewModel.Focus?

    var body: some View {
        DScreen(
            leading: {
                DButton(
                    image: .hambergerMenu,
                    action: viewModel.onTapSettings
                )
                .dStyle(.circle)
                .disabled(viewModel.isLoading)
            },
            titleContent: {
                DButton(
                    image: .down,
                    title: viewModel.usExaminationType.getLocalizedTitle(for: Locale.current),
                    action: viewModel.onTapUSExaminationType
                )
                .dStyle(.primaryChip)
                .disabled(viewModel.isLoading)
                .contentTransition(.opacity)
                .animation(
                    theme.animation,
                    value: viewModel.usExaminationType.id
                )
            },
            onTapBody: viewModel.unfocus,
            keyboardToolbar: {
                if focus != nil {
                    DToolbar(
                        upAccessibilityLabel: .buttonBack,
                        downAccessibilityLabel: .buttonNext,
                        doneAccessibilityLabel: .buttonDone,
                        onTapUp: viewModel.canFocusPreviousField ? { viewModel.onTapToolbarUp() } : nil,
                        onTapDown: viewModel.canFocusNextField ? { viewModel.onTapToolbarDown() } : nil,
                        onTapDone: viewModel.unfocus,
                        trailButtons: [
                            viewModel.isSpeechButtonVisible
                                ? DToolbarButton(
                                    accessibilityLabel: .buttonSpeech,
                                    style: .primaryDefault,
                                    badge: viewModel.speechButtonBadge,
                                    content: .icon(.microphone),
                                    action: viewModel.onTapSpeech
                                )
                                : nil,
                            DToolbarButton(
                                accessibilityLabel: .buttonGenerate,
                                style: .primaryDefault,
                                content: .text(.buttonGenerate),
                                action: viewModel.onTapScan
                            ),
                        ].compactMap { $0 }
                    )
                    .disabled(viewModel.isLoading)
                }
            },
            content: { toolbarHeight, _ in
                ZStack(
                    alignment: .bottom
                ) {
                    DFocusScrollView(
                        focus: focus
                    ) {
                        VStack(
                            alignment: .leading,
                            spacing: .zero
                        ) {
                            if viewModel.isPhotoEmptyStateVisible {
                                ScanMediaButtonView(
                                    action: viewModel.onTapImport
                                )
                                .disabled(viewModel.isMediaSelectionDisabled)
                                .padding(.horizontal, size.s16)
                                .padding(.bottom, size.s4)
                                .transition(
                                    .move(edge: .top)
                                        .combined(with: .opacity)
                                )
                            }

                            ScanPhotoListView()

                            ScanFormView(
                                focus: $focus
                            )
                        }
                        .padding(.top, toolbarHeight + size.s16)
                        .padding(.bottom, size.s136 * 2)
                        .animation(
                            theme.animation,
                            value: viewModel.photos
                        )
                    }
                    .disabled(viewModel.isLoading)

                    ScanBottomView()
                }
            }
        )
        .onSubmit {
            viewModel.onSubmit()
        }
        .onChange(of: focus, initial: true) { _, newValue in
            guard viewModel.focus != newValue else { return }
            viewModel.focus = newValue
        }
        .onChange(of: viewModel.focus, initial: true) { _, newValue in
            guard focus != newValue else { return }
            focus = newValue
        }
        .onAppear {
            viewModel.onAppear()
        }
        .environmentObject(viewModel)
    }
}
