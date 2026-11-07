import DoglyadUI
import SwiftUI

struct StorageClearAllBottomSheetView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: StorageClearAllViewModel

    var body: some View {
        DInfoBottomSheet(
            fraction: 0.5,
            title: l10n[
                .storageClearAllWarningTitle,
            ],
            image: .doglyadQuestion,
            description: l10n[
                .storageClearAllWarningDescription,
            ],
            buttonTitle: l10n[
                .buttonClearAll,
            ],
            action: viewModel.onTapConfirm,
        )
        .environmentObject(
            viewModel,
        )
        .onAppear(
            perform: viewModel.onAppear,
        )
    }
}
