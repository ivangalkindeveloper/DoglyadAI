import DoglyadUI
import SwiftUI

struct SelectTemplateStateView: DViewProtocol {
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
        case (_ as SelectTemplateLoadingState, true):
            TemplateListLoadingView()
        case (_ as SelectTemplateEmptyState, true):
            TemplateListEmptyView()
        case (_ as SelectTemplateFailedState, true):
            LoadingErrorView(
                onRetry: viewModel.onTapRetry,
            )
        default:
            EmptyView()
        }
    }
}
