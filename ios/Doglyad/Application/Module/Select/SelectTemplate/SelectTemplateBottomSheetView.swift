import DoglyadUI
import SwiftUI

struct SelectTemplateBottomSheetView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: SelectTemplateViewModel

    var body: some View {
        DBottomSheet(
            title: l10n[
                .selectTemplateTitle,
            ],
            fraction: 0.6,
        ) { toolbarHeight, bottomHeight in
            ScrollView(
                showsIndicators: false,
            ) {
                LazyVStack(
                    alignment: .leading,
                    spacing: size.s4,
                ) {
                    let isLoading = switch viewModel.state {
                    case _ as SelectTemplateLoadingState: true
                    default: false
                    }
                    SelectTemplateStateView(
                        isLoading: isLoading,
                    )
                }
                .padding(
                    .top,
                    size.s16,
                )
                .padding(
                    .horizontal,
                    size.s16,
                )
                .padding(
                    .bottom,
                    bottomHeight + size.s16,
                )
            }
            .contentMargins(
                .top,
                toolbarHeight,
                for: .scrollContent,
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
