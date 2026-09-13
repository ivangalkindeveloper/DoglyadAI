import DoglyadUI
import SwiftUI

struct TemplateListScreenView: DView {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var container: DependencyContainer

    @StateObject var viewModel: TemplateListViewModel

    var body: some View {
        DScreen(
            title: .templateListTitle,
            onTapBack: viewModel.onTapBack,
            content: { toolbarInset, _ in
                ZStack(
                    alignment: .bottom
                ) {
                    ScrollView(
                        showsIndicators: false
                    ) {
                        VStack(
                            alignment: .leading,
                            spacing: .zero
                        ) {
                            if viewModel.templates.isEmpty {
                                TemplateListEmptyView()
                            } else {
                                ForEach(viewModel.templates) { template in
                                    TemplateListItemCardView(
                                        examinationTypeTitle: template.usExaminationType.getLocalizedTitle(
                                            for: Locale.current
                                        ),
                                        templateContent: template.content,
                                        action: {
                                            viewModel.onTapTemplate(template)
                                        }
                                    )
                                    .padding(.bottom, size.s4)
                                }
                            }
                        }
                        .padding(size.s16)
                        .padding(.top, toolbarInset)
                        .padding(.bottom, size.s64)
                    }
                }
            },
            bottom: {
                DButton(
                    title: .templateListAddButton,
                    action: viewModel.onTapAdd
                )
                .dStyle(.primaryButton)
                .padding(size.s16)
            }
        )
        .onAppear {
            viewModel.onAppear()
        }
        .environmentObject(viewModel)
    }
}
