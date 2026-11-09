import DoglyadUI
import SwiftUI

struct ScanScreenView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: ScanViewModel
    @FocusState private var focus: ScanFocus?

    var body: some View {
        let (isProcessing, isMediaSelectionDisabled): (Bool, Bool) = switch viewModel.state {
        case _ as ScanGenerationLoadingState: (true, true)
        default: (false, viewModel.isPhotoLimitReached)
        }

        DScreen(
            leading: {
                DButton(
                    image: .hambergerMenu,
                    action: viewModel.onTapSettings,
                    isDisabled:
                    isProcessing,
                    accessibilityIdentifier: "scan.settings",
                )
                .dStyle(
                    .circle,
                )
            },
            titleContent: {
                DButton(
                    image: .down,
                    title: viewModel.usExaminationType.localizedTitle,
                    action: viewModel.onTapUSExaminationType,
                    isDisabled:
                    isProcessing,
                    accessibilityIdentifier: "scan.type",
                )
                .dStyle(
                    .primaryChip,
                )
                .contentTransition(
                    .opacity,
                )
            },
            onTapBody: viewModel.unfocus,
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
                    ScanBottomView()
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                )
            },
            keyboardToolbar: {
                if focus != nil {
                    ScanKeyboardToolbarView(
                        isProcessing: isProcessing,
                    )
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
            viewModel.onResume()
        }
        .environmentObject(
            viewModel,
        )
    }
}
