import DoglyadUI
import SwiftUI

struct ScanScreenView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: ScanViewModel
    @FocusState private var focus: ScanFocus?

    var body: some View {
        let (isProcessing, isMediaSelectionDisabled): (Bool, Bool) = switch viewModel.state {
        case _ as ScanInitializationLoadingState, _ as ScanGenerationLoadingState, _ as ScanReportSaveLoadingState, _ as ScanClearLoadingState: (true, true)
        default: (false, viewModel.isPhotoLimitReached)
        }

        DScreen(
            leading: {
                DButton(
                    image: .hambergerMenu,
                    accessibilityIdentifier: "scan.settings",
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
                    accessibilityIdentifier: "scan.type",
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
                    ScanKeyboardToolbarView(
                        isProcessing: isProcessing,
                    )
                }
            },
            content: { toolbarHeight, _ in
                ZStack(
                    alignment: .bottom,
                ) {
                    ScanContentStateView(
                        focus: $focus,
                        toolbarHeight: toolbarHeight,
                        isProcessing: isProcessing,
                        isMediaSelectionDisabled: isMediaSelectionDisabled,
                    )
                    if !(viewModel.state is ScanInitializationFailedState) {
                        ScanBottomView()
                    }
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                )
            },
        )
        .onSubmit {
            viewModel.onSubmit()
        }
        .onChange(
            of: focus,
            initial: true,
        ) { _, newValue in
            guard viewModel.focus != newValue else {
                return
            }
            viewModel.onFocusChanged(
                newValue,
            )
        }
        .onChange(
            of: viewModel.focus,
            initial: true,
        ) { _, newValue in
            guard focus != newValue else {
                return
            }
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
