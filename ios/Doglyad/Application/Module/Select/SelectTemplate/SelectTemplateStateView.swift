import DoglyadUI
import SwiftUI

struct SelectTemplateStateView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: SelectTemplateViewModel
    let isLoading: Bool

    var body: some View {
        switch (viewModel.state, viewModel.templates.isEmpty) {
        case (_, false):
            ForEach(
                viewModel.templates,
            ) { template in
                TemplateListItemCardView(
                    template: template,
                    action: {
                        viewModel.onTemplateTap(
                            template,
                        )
                    },
                    isSelected: viewModel.currentTemplateID == template.id,
                )
            }.disabled(
                isLoading,
            )
        case (_ as SelectTemplateTemplatesLoadingState, true):
            TemplateListLoadingView()
        case (_ as SelectTemplateEmptyState, true):
            TemplateListEmptyView()
        case (_ as SelectTemplateFailedState, true):
            VStack(
                spacing: size.s16,
            ) {
                ErrorBodyView(
                    description: l10n.text(
                        .errorUnknownDescription,
                    ),
                )

                DButton(
                    title: l10n[
                        .buttonUpdate,
                    ],
                    action: viewModel.onTapRetry,
                )
                .dStyle(
                    .primaryChip,
                )
            }
            .padding(
                size.s16,
            )
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
            )
        default:
            EmptyView()
        }
    }
}
