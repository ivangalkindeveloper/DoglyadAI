import DoglyadUI
import Foundation
import SwiftUI

struct SelectNeuralModelBottomSheetView: View {
    @EnvironmentObject private var theme: DTheme
    private var color: DColor { theme.color }
    private var size: DSize { theme.size }
    private var typography: DTypography { theme.typography }

    @StateObject var viewModel: SelectNeuralModelViewModel

    var body: some View {
        DBottomSheet(
            title: .settingsNeuralModelTitle,
            fraction: 0.8
        ) { toolbarHeight, bottomHeight in
            ScrollView(
                showsIndicators: false
            ) {
                VStack(
                    spacing: .zero
                ) {
                    ForEach(viewModel.models) { model in
                        DBadge([
                            DBadgeItem(
                                .entitlementPro,
                                isVisible: viewModel.isProBadgeVisible(for: model),
                                isShimmering: true
                            ),
                            DBadgeItem(
                                .neuralModelComingSoonBadge,
                                isVisible: viewModel.isComingSoonBadgeVisible(for: model)
                            ),
                        ]) {
                            DListButtonCard(
                                title: LocalizedStringResource(stringLiteral: model.title),
                                description: """
                                (\(model.id))
                                \(String(localized: .neuralModelContextLengthDescription)) \(model.contextLength)
                                \(model.getLocalizedDescription(for: Locale.current))
                                """,
                                action: {
                                    viewModel.onModelTap(model)
                                },
                                isSelected: viewModel.isSelected(model)
                            )
                            .disabled(!viewModel.isSelectionEnabled(for: model))
                        }
                    }
                    .padding(.bottom, size.s8)
                }
                .padding(.top, toolbarHeight)
                .padding(size.s16)
                .padding(.bottom, bottomHeight)
            }
        }
        bottom: {
            DText(
                .neuralModelAddingDescription
            )
            .dStyle(
                font: typography.textSmall,
                color: color.grayscalePlacehold,
                alignment: .center
            )
            .padding(.top, size.s16)
            .padding(.horizontal, size.s16)
        }
        .onAppear(perform: viewModel.onAppear)
    }
}
