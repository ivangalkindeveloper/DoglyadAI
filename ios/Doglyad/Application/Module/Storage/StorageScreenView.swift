import DoglyadUI
import SwiftUI

struct StorageScreenView: DView {
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: StorageViewModel

    var body: some View {
        DScreen(
            title: .storageTitle,
            onTapBack: viewModel.onTapBack
        ) { toolbarInset, _ in
            ScrollView(
                showsIndicators: false
            ) {
                VStack(
                    spacing: size.s8
                ) {
                    DListButtonCard(
                        title: .storageClearConclusionsTitle,
                        description: .storageClearConclusionsDescription,
                        action: viewModel.onTapClearConclusions
                    )
                    DListButtonCard(
                        title: .storageClearAllTitle,
                        description: .storageClearAllDescription,
                        action: viewModel.onTapClearAll
                    )
                }
                .padding(size.s16)
                .padding(.top, toolbarInset)
                .padding(.bottom, size.s32)
            }
        }
        .onAppear(perform: viewModel.onAppear)
        .environmentObject(viewModel)
    }
}
