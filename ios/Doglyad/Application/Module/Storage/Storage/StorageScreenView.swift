import DoglyadUI
import SwiftUI

struct StorageScreenView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: StorageViewModel

    var body: some View {
        let isProcessing = switch viewModel.state {
        case _ as StorageProtocolsClearLoadingState, _ as StorageSpeechModelDeleteLoadingState, _ as StorageAllClearLoadingState: true
        default: false
        }

        DScreen(
            title: l10n[
                .storageTitle,
            ],
            onTapBack: viewModel.onTapBack,
        ) { toolbarInset, _ in
            DScrollVStack(
                alignment: .center,
                spacing: size.s8,
                padding: EdgeInsets(
                    top: size.s16 + toolbarInset,
                    leading: size.s16,
                    bottom: size.s16 + size.s32,
                    trailing: size.s16,
                ),
            ) {
                Group {
                    DListButtonCard(
                        title: l10n[
                            .storageClearProtocolsTitle,
                        ],
                        description: l10n[
                            .storageClearProtocolsDescription,
                        ],
                        action: viewModel.onTapClearProtocols,
                    )
                    if viewModel.isSpeechModelAvailable {
                        DListButtonCard(
                            title: l10n[
                                .storageDeleteSpeechModelButton,
                            ],
                            description: l10n[
                                .storageDeleteSpeechModelDescription,
                            ],
                            action: viewModel.onTapDeleteSpeechModel,
                        )
                    }
                    DListButtonCard(
                        title: l10n[
                            .storageClearAllTitle,
                        ],
                        description: l10n[
                            .storageClearAllDescription,
                        ],
                        action: viewModel.onTapClearAll,
                    )
                }.disabled(
                    isProcessing,
                )
            }
        }
        .onAppear(
            perform: viewModel.onAppear,
        )
        .onDisappear(
            perform: viewModel.onDisappear,
        )
        .environmentObject(
            viewModel,
        )
    }
}
