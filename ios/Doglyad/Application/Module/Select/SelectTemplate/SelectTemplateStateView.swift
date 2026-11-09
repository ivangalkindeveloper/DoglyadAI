import DoglyadUI
import SwiftUI

struct SelectTemplateStateView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: SelectTemplateViewModel

    var body: some View {
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
        }
    }
}
