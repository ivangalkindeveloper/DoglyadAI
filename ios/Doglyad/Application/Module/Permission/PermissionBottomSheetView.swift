import DoglyadUI
import Foundation
import SwiftUI

struct PermissionBottomSheetView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: PermissionViewModel

    var body: some View {
        DInfoBottomSheet(
            fraction: 0.5,
            title: viewModel.title,
            image: .doglyadQuestion,
            description: viewModel.description,
            buttonTitle: l10n[
                .buttonOpenSettings,
            ],
            action: viewModel.onTapOpenSettings,
        )
        .onAppear(
            perform: viewModel.onAppear,
        )
        .environmentObject(
            viewModel,
        )
    }
}
