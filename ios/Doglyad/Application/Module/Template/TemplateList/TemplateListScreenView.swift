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
            content: { toolbarInset, bottomInset in
                ZStack(
                    alignment: .bottom
                ) {
                    ScrollView(
                        showsIndicators: false
                    ) {
                        VStack(
                            alignment: .leading,
                            spacing: size.s4
                        ) {
                            if viewModel.templates.isEmpty {
                                TemplateListEmptyView()
                                    .transition(.opacity)
                            } else {
                                ForEach(viewModel.templates) { template in
                                    TemplateListItemCardView(
                                        template: template,
                                        action: {
                                            viewModel.onTapTemplate(template)
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.top, toolbarInset + size.s8)
                        .padding(.horizontal, size.s16)
                        .padding(.bottom, bottomInset + size.s16)
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
        .animation(theme.animation, value: viewModel.templates)
        .onAppear {
            viewModel.onAppear()
        }
        .environmentObject(viewModel)
    }
}
