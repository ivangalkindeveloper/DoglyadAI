import DoglyadUI
import SwiftUI

struct StorageClearProtocolsBottomSheetView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: StorageClearProtocolsViewModel

    init(
        viewModel: @autoclosure @escaping () -> StorageClearProtocolsViewModel,
    ) {
        _viewModel = StateObject(
            wrappedValue: viewModel(),
        )
    }

    var body: some View {
        DInfoBottomSheet(
            fraction: 0.5,
            title: l10n[
                .storageClearProtocolsWarningTitle,
            ],
            image: .doglyadQuestion,
            description: l10n[
                .storageClearProtocolsWarningDescription,
            ],
            buttonTitle: l10n[
                .buttonDelete,
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
