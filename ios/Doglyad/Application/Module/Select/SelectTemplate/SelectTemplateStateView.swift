import DoglyadUI
import SwiftUI

struct SelectTemplateStateView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: SelectTemplateViewModel

    init() {}

    var body: some View {
        ForEach(
            viewModel.state.templates,
        ) { template in
            TemplateListItemCardView(
                template: template,
                action: {
                    viewModel.onTemplateTap(
                        template,
                    )
                },
                isSelected: viewModel.state.currentTemplateID == template.id,
            )
        }
    }
}
