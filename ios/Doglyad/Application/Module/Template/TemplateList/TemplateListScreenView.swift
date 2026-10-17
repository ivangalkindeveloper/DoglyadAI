import DoglyadUI
import SwiftUI

struct TemplateListScreenView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var container: DependencyContainer

    @StateObject var viewModel: TemplateListViewModel

    var body: some View {
        DScreen(
            title: l10n[
                .templateListTitle,
            ],
            onTapBack: viewModel.onTapBack,
            content: { toolbarInset, bottomInset in
                ZStack(
                    alignment: .bottom,
                ) {
                    ScrollView(
                        showsIndicators: false,
                    ) {
                        VStack(
                            alignment: .leading,
                            spacing: size.s4,
                        ) {
                            switch viewModel.state {
                            case _ as TemplateListLoadingState:
                                TemplateListLoadingView()
                                    .transition(
                                        .opacity,
                                    )
                            case _ as TemplateListEmptyState:
                                TemplateListEmptyView()
                                    .transition(
                                        .opacity,
                                    )
                            case let state as TemplateListContentState:
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
                            case _ as TemplateListFailedState:
                                LoadingErrorView(
                                    onRetry: viewModel.onTapRetry,
                                )
                            default:
                                DUnexpectedStateView(
                                    state: viewModel.state,
                                )
                            }
                        }
                        .padding(
                            .top,
                            toolbarInset + size.s8,
                        )
                        .padding(
                            .horizontal,
                            size.s16,
                        )
                        .padding(
                            .bottom,
                            bottomInset + size.s16,
                        )
                    }
                }
            },
            bottom: {
                DButton(
                    title: l10n[
                        .templateListAddButton,
                    ],
                    action: viewModel.onTapAdd,
                )
                .dStyle(
                    .primaryButton,
                )
                .padding(
                    size.s16,
                )
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
