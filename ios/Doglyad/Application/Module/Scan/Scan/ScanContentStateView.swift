import DoglyadUI
import SwiftUI

struct ScanContentStateView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: ScanViewModel
    let focus: FocusState<ScanFocus?>.Binding
    let toolbarHeight: CGFloat
    let isProcessing: Bool
    let isMediaSelectionDisabled: Bool

    var body: some View {
        switch viewModel.state {
        case _ as ScanInitializationFailedState:
            LoadingErrorView(
                onRetry: viewModel.onTapRetryInitialization,
            )
        default:
            DFocusScrollView(
                focus: focus.wrappedValue,
            ) {
                VStack(
                    alignment: .leading,
                    spacing: .zero,
                ) {
                    if viewModel.photos.isEmpty {
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
                    }

                    ScanPhotoListView()

                    ScanFormView(
                        focus: focus,
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
    }
}
