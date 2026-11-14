import DoglyadUI
import SwiftUI

struct StorageClearSpeechModelBottomSheetView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: StorageClearSpeechModelViewModel

    init(
        viewModel: @autoclosure @escaping () -> StorageClearSpeechModelViewModel,
    ) {
        _viewModel = StateObject(
            wrappedValue: viewModel(),
        )
    }

    var body: some View {
        DInfoBottomSheet(
            fraction: 0.5,
            title: l10n[
                .storageClearSpeechModelWarningTitle,
            ],
            image: .doglyadQuestion,
            description: l10n[
                .storageClearSpeechModelWarningDescription,
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
        .onDisappear(
            perform: viewModel.onDisappear,
        )
    }
}
