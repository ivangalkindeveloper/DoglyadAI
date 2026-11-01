import DoglyadUI
import SwiftUI

struct SelectTranscriptParserBottomSheetView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: SelectTranscriptParserViewModel

    var body: some View {
        DBottomSheet(
            title: l10n[
                .selectTranscriptParserTitle,
            ],
            fraction: 0.8,
        ) { toolbarHeight, bottomHeight in
            DScrollVStack(
                spacing: size.s8,
                padding: EdgeInsets(
                    top: toolbarHeight + size.s16,
                    leading: size.s16,
                    bottom: size.s16 + bottomHeight,
                    trailing: size.s16,
                ),
            ) {
                ForEach(
                    viewModel.options,
                    id: \.self,
                ) { option in
                    DListButtonCard(
                        title: l10n[
                            option.titleKey,
                        ],
                        description: l10n[
                            option.descriptionKey,
                        ],
                        action: {
                            viewModel.onSelect(
                                option,
                            )
                        },
                        isSelected: viewModel.currentValue == option,
                    )
                    .disabled(
                        !viewModel.isSelectionEnabled(
                            for: option,
                        ),
                    )
                }
            }
        }
        .environmentObject(
            viewModel,
        )
        .onAppear(
            perform: viewModel.onAppear,
        )
    }
}
