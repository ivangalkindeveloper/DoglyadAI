import DoglyadUI
import SwiftUI

struct WebDocumentBottomSheetView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: WebDocumentViewModel

    var body: some View {
        DBottomSheet(
            title: viewModel.title,
            fraction: 0.8,
        ) { toolbarHeight, bottomHeight in
            switch viewModel.state {
            case _ as WebDocumentFailedState:
                VStack(
                    spacing: size.s16,
                ) {
                    ErrorBodyView(
                        description: l10n.text(
                            .errorUnknownDescription,
                        ),
                    )

                    DButton(
                        title: l10n[
                            .buttonRetry,
                        ],
                        action: viewModel.onTapRetry,
                    )
                    .dStyle(
                        .primaryChip,
                    )
                }
                .padding(
                    size.s16,
                )
                .padding(
                    .top,
                    toolbarHeight,
                )
                .padding(
                    .bottom,
                    bottomHeight,
                )
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                )
                .accessibilityIdentifier(
                    "webDocument.failed",
                )
            default:
                WebDocumentContentView(
                    state: viewModel.state,
                    topInset: toolbarHeight,
                    bottomInset: bottomHeight,
                )
                .edgesIgnoringSafeArea(
                    .bottom,
                )
            }
        }
        .environmentObject(
            viewModel,
        )
        .onAppear(
            perform: viewModel.onAppear,
        )
    }
}
