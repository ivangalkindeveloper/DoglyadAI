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
            ScrollView(
                showsIndicators: false,
            ) {
                VStack(
                    alignment: .leading,
                    spacing: size.s8,
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
                            action: { viewModel.onSelect(
                                option,
                            ) },
                            isSelected: viewModel.currentValue == option,
                        )
                        .disabled(
                            !viewModel.isSelectionEnabled(
                                for: option,
                            ),
                        )
                    }
                }
                .padding(
                    .top,
                    toolbarHeight,
                )
                .padding(
                    size.s16,
                )
                .padding(
                    .bottom,
                    bottomHeight,
                )
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
