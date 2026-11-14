import SwiftUI

struct NewVersionScreenView: View {
    @StateObject var viewModel: NewVersionViewModel

    init(
        viewModel: @autoclosure @escaping () -> NewVersionViewModel,
    ) {
        _viewModel = StateObject(
            wrappedValue: viewModel(),
        )
    }

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
