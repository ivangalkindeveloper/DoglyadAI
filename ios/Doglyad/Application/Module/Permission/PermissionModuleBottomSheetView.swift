import SwiftUI

struct PermissionModuleBottomSheetView: View {
    @StateObject var viewModel: PermissionBottomSheetViewModel

    let title: LocalizedStringResource
    let description: LocalizedStringResource

    var body: some View {
        PermissionBottomSheet(
            title: title,
            description: description
        )
        .onAppear(perform: viewModel.onAppear)
    }
}
