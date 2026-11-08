import DoglyadUI
import SwiftUI

struct ReadyMadeTemplateListScreenView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: ReadyMadeTemplateListViewModel
    @FocusState private var focus: ReadyMadeTemplateListFocus?

    var body: some View {
        DScreen(
            title: l10n[
                .readyMadeTemplateListTitle,
            ],
            onTapBack: viewModel.onTapBack,
            toolbarContent: {
                ReadyMadeTemplateListSearchView(
                    focus: $focus,
                )
            },
            onTapBody: viewModel.unfocus,
            keyboardToolbar: {
                if focus != nil {
                    DToolbar(
                        onTapDone: viewModel.unfocus,
                    )
                }
            },
            content: { toolbarInset, _ in
                switch viewModel.state {
                case _ as ReadyMadeTemplateListLoadingState:
                    DShimmerPlaceholder().frame(
                        width: size.s64,
                        height: size.s8,
                    )
                    .tint(
                        color.primaryDefault,
                    )
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                    )
                    .padding(
                        .top,
                        toolbarInset,
                    )
                    .transition(
                        .opacity,
                    )
                case _ as ReadyMadeTemplateListFailedState:
                    VStack(
                        spacing: size.s16,
                    ) {
                        ErrorBodyView(
                            description: l10n.text(
                                .readyMadeTemplateListErrorDescription,
                            ),
                        )

                        DButton(
                            title: l10n[
                                .readyMadeTemplateListRetryButton,
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
                    .padding(
                        .top,
                        toolbarInset,
                    )
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                    )
                    .transition(
                        .opacity,
                    )
                case _ as ReadyMadeTemplateListSuccessState:
                    ScrollView(
                        showsIndicators: false,
                    ) {
                        LazyVStack(
                            alignment: .leading,
                            spacing: size.s4,
                        ) {
                            if viewModel.filteredTemplates.isEmpty {
                                DText(
                                    viewModel.emptyDescription,
                                )
                                .dStyle(
                                    font: typography.textSmall,
                                    color: color.grayscalePlacehold,
                                )
                                .multilineTextAlignment(
                                    .center,
                                )
                                .frame(
                                    maxWidth: .infinity,
                                )
                                .transition(
                                    .opacity,
                                )
                                .padding(
                                    size.s16,
                                )
                            } else {
                                ForEach(
                                    viewModel.filteredTemplates,
                                ) { template in
                                    ReadyMadeTemplateListItemCardView(
                                        template: template,
                                        examinationTypeTitle: viewModel.examinationTypeTitle(
                                            for: template,
                                        ),
                                        action: {
                                            viewModel.onTapTemplate(
                                                template,
                                            )
                                        },
                                    )
                                }
                            }
                        }
                        .padding(
                            .top,
                            toolbarInset + size.s16,
                        )
                        .padding(
                            .horizontal,
                            size.s16,
                        )
                        .padding(
                            .bottom,
                            size.s32,
                        )
                    }
                    .transition(
                        .opacity,
                    )
                default: EmptyView()
                }
            },
        )
        .onAppear(
            perform: viewModel.onAppear,
        )
        .onSubmit {
            viewModel.unfocus()
        }
        .onChange(
            of: focus,
            initial: true,
        ) { _, newValue in
            guard viewModel.focus != newValue else {
                return
            }
            viewModel.onFocusChanged(
                newValue,
            )
        }
        .onChange(
            of: viewModel.focus,
            initial: true,
        ) { _, newValue in
            guard focus != newValue else {
                return
            }
            focus = newValue
        }
        .environmentObject(
            viewModel,
        )
    }
}
