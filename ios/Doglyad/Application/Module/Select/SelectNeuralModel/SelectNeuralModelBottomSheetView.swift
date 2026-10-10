import DoglyadUI
import Foundation
import SwiftUI

struct SelectNeuralModelBottomSheetView: DView {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: SelectNeuralModelViewModel

    var body: some View {
        DBottomSheet(
            title: l10n[
                .settingsNeuralModelTitle,
            ],
            fraction: 0.8,
        ) { toolbarHeight, bottomHeight in
            ScrollView(
                showsIndicators: false,
            ) {
                VStack(
                    spacing: .zero,
                ) {
                    ForEach(
                        viewModel.models,
                    ) { model in
                        DBadge(
                            [
                                DBadgeItem(
                                    l10n[
                                        .entitlementPro,
                                    ],
                                    isVisible: viewModel.isProBadgeVisible(
                                        for: model,
                                    ),
                                    isShimmering: true,
                                ),
                                DBadgeItem(
                                    l10n[
                                        .neuralModelComingSoonBadge,
                                    ],
                                    isVisible: viewModel.isComingSoonBadgeVisible(
                                        for: model,
                                    ),
                                ),
                            ],
                        ) {
                            DListButtonCard(
                                title: LocalizedStringResource(
                                    stringLiteral: model.title,
                                ),
                                description: l10n.resource(
                                    .neuralModelDetailsDescription,
                                    values: [
                                        "id": model.id,
                                        "contextLabel": l10n.text(
                                            .neuralModelContextLengthDescription,
                                        ),
                                        "contextLength": String(
                                            model.contextLength,
                                        ),
                                        "description": model.description,
                                    ],
                                ),
                                action: {
                                    viewModel.onModelTap(
                                        model,
                                    )
                                },
                                isSelected: viewModel.isSelected(
                                    model,
                                ),
                            )
                            .disabled(
                                !viewModel.isSelectionEnabled(
                                    for: model,
                                ),
                            )
                        }
                    }
                    .padding(
                        .bottom,
                        size.s8,
                    )
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
        bottom: {
            DText(
                l10n[
                    .neuralModelAddingDescription,
                ],
            )
            .dStyle(
                font: typography.textSmall,
                color: color.grayscalePlacehold,
                alignment: .center,
            )
            .padding(
                .top,
                size.s16,
            )
            .padding(
                .horizontal,
                size.s16,
            )
        }
        .onAppear(
            perform: viewModel.onAppear,
        )
    }
}
