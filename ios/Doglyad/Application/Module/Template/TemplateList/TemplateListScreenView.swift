import DoglyadUI
import SwiftUI

struct TemplateListScreenView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: TemplateListViewModel

    init(
        viewModel: @autoclosure @escaping () -> TemplateListViewModel,
    ) {
        _viewModel = StateObject(
            wrappedValue: viewModel(),
        )
    }

    var body: some View {
        DScreen(
            title: l10n[
                .templateListTitle,
            ],
            onTapBack: viewModel.onTapBack,
            content: { toolbarInset, bottomInset in
                let padding = EdgeInsets(
                    top: toolbarInset + size.s8,
                    leading: size.s16,
                    bottom: bottomInset + size.s16,
                    trailing: size.s16,
                )
                switch viewModel.state {
                case _ as TemplateListInitialState: EmptyView()
                case _ as TemplateListEmptyState:
                    DScrollVStack(
                        spacing: size.s4,
                        padding: padding,
                    ) {
                        TemplateListEmptyView()
                    }
                case let state as TemplateListContentState:
                    DScrollVStack(
                        spacing: size.s4,
                        padding: padding,
                    ) {
                        ForEach(
                            state.templates,
                        ) { template in
                            TemplateListItemCardView(
                                template: template,
                                action: {
                                    viewModel.onTapTemplate(
                                        template,
                                    )
                                },
                            )
                        }
                    }
                case _ as TemplateListErrorState:
                    ErrorBodyView(
                        description: l10n.text(
                            .errorUnknownDescription,
                        ),
                    )
                    .padding(
                        padding,
                    )
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                    )
                default:
                    EmptyView()
                }
            },
            bottom: {
                TemplateListBottomView()
            },
        )
        .onAppear {
            viewModel.onAppear()
        }
        .environmentObject(
            viewModel,
        )
    }
}
