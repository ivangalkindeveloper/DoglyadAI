import DoglyadUI
import SwiftUI

struct ScanContentStateView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: ScanViewModel
    let focus: FocusState<ScanFocus?>.Binding
    let toolbarHeight: CGFloat
    let isProcessing: Bool
    let isMediaSelectionDisabled: Bool

    var body: some View {
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
                        isDisabled: isMediaSelectionDisabled || isProcessing,
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

                ScanPhotoListView(
                    isDisabled:
                    isProcessing,
                )

                ScanFormView(
                    focus: focus,
                    isDisabled:
                    isProcessing,
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
    }
}
