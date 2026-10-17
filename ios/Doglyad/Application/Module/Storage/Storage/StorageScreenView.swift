import DoglyadUI
import SwiftUI

struct StorageScreenView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: StorageViewModel

    var body: some View {
        let isProcessing = switch viewModel.state {
        case _ as StorageLoadingState: true
        default: false
        }

        DScreen(
            title: l10n[
                .storageTitle,
            ],
            onTapBack: viewModel.onTapBack,
        ) { toolbarInset, _ in
            ScrollView(
                showsIndicators: false,
            ) {
                VStack(
                    spacing: size.s8,
                ) {
                    DListButtonCard(
                        title: l10n[
                            .storageClearProtocolsTitle,
                        ],
                        description: l10n[
                            .storageClearProtocolsDescription,
                        ],
                        action: viewModel.onTapClearProtocols,
                    )
                    DListButtonCard(
                        title: l10n[
                            .storageClearAllTitle,
                        ],
                        description: l10n[
                            .storageClearAllDescription,
                        ],
                        action: viewModel.onTapClearAll,
                    )
                }
                .disabled(
                    isProcessing,
                )
                .padding(
                    size.s16,
                )
                .padding(
                    .top,
                    toolbarInset,
                )
                .padding(
                    .bottom,
                    size.s32,
                )
            }
        }
        .onAppear(
            perform: viewModel.onAppear,
        )
        .environmentObject(
            viewModel,
        )
    }
}
