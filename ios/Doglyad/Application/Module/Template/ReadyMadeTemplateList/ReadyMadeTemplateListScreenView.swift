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
            content: { toolbarInset, bottomInset in
                switch viewModel.state {
                case _ as ReadyMadeTemplateListLoadingState:
                    DScrollVStack(
                        spacing: size.s4,
                        padding: EdgeInsets(
                            top: toolbarInset + size.s16,
                            leading: size.s16,
                            bottom: bottomInset + size.s16,
                            trailing: size.s16,
                        ),
                    ) {
                        ForEach(
                            0 ..< 5,
                            id: \.self,
                        ) { _ in
                            ReadyMadeTemplateListLoadingCardView()
                        }
                    }
                case _ as ReadyMadeTemplateListErrorState:
                    ErrorBodyView(
                        description: l10n.text(
                            .readyMadeTemplateListErrorDescription,
                        ),
                    )
                    .padding(
                        size.s16,
                    )
                    .padding(
                        .top,
                        toolbarInset,
                    )
                    .padding(
                        .bottom,
                        bottomInset,
                    )
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                    )
                    .transition(
                        .opacity,
                    )
                case let state as ReadyMadeTemplateListSuccessState where state.templates.isEmpty:
                    EmptyTemplatesBodyView(
                        description: viewModel.emptyDescription,
                    )
                    .padding(
                        .top,
                        toolbarInset,
                    )
                    .padding(
                        .bottom,
                        bottomInset,
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
                            bottomInset + size.s32,
                        )
                    }
                    .transition(
                        .opacity,
                    )
                default: EmptyView()
                }
            },
            bottom: {
                ReadyMadeTemplateListBottomView()
            },
            keyboardToolbar: {
                if focus != nil {
                    DToolbar(
                        onTapDone: viewModel.unfocus,
                    )
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
