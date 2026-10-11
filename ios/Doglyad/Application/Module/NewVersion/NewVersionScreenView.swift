import SwiftUI

struct NewVersionScreenView: View {
    @StateObject var viewModel: NewVersionViewModel

    var body: some View {
        NewVersionView(
            onTapUpdate: viewModel.onTapUpdate,
        )
        .environmentObject(
            viewModel,
        )
        .onAppear(
            perform: viewModel.onAppear,
        )
    }
}
