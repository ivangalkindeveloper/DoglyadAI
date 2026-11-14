import DoglyadUI
import SwiftUI

struct TemplateDeleteBottomSheetView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: TemplateDeleteViewModel

    init(
        viewModel: @autoclosure @escaping () -> TemplateDeleteViewModel,
    ) {
        _viewModel = StateObject(
            wrappedValue: viewModel(),
        )
    }

    var body: some View {
        DInfoBottomSheet(
            fraction: 0.5,
            title: l10n[
                .templateDeleteTitle,
            ],
            image: .doglyadQuestion,
            description: l10n[
                .templateDeleteDescription,
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
