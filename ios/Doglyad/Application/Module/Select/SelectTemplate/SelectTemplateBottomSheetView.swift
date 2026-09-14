import DoglyadUI
import SwiftUI

struct SelectTemplateBottomSheetView: DView {
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: SelectTemplateViewModel

    var body: some View {
        DBottomSheet(
            title: .selectTemplateTitle,
            fraction: 0.6
        ) { toolbarHeight, bottomHeight in
            ScrollView(
                showsIndicators: false
            ) {
                LazyVStack(
                    alignment: .leading,
                    spacing: size.s4
                ) {
                    ForEach(viewModel.templates) { template in
                        TemplateListItemCardView(
                            template: template,
                            action: {
                                viewModel.onTemplateTap(template)
                            },
                            isSelected: viewModel.isSelected(template)
                        )
                    }
                }
                .padding(.top, size.s16)
                .padding(.horizontal, size.s16)
                .padding(.bottom, bottomHeight + size.s16)
            }
            .contentMargins(.top, toolbarHeight, for: .scrollContent)
        }
        .onAppear(perform: viewModel.onAppear)
    }
}
