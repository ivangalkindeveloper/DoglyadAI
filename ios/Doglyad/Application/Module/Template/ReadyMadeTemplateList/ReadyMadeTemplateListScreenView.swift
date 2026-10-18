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
                switch viewModel.state {
                case _ as ReadyMadeTemplateListContentState:
                    DTextField(
                        controller: viewModel.controller,
                        focus: DTextFieldFocus(
                            value: .search,
                            state: $focus,
                        ),
                        title: l10n[
                            .readyMadeTemplateListSearchLabel,
                        ],
                        placeholder: l10n[
                            .readyMadeTemplateListSearchPlaceholder,
                        ],
                        mode: DTextFieldSingleLineMode(
                            submitLabel: .done,
                        ),
                        autocapitalization: .never,
                    )
                    .padding(
                        .top,
                        size.s8,
                    )
                    .padding(
                        .horizontal,
                        size.s16,
                    )
                case _ as ReadyMadeTemplateListLoadingState, _ as ReadyMadeTemplateListFailedState:
                    EmptyView()
                default: EmptyView()
                }
            },
            onTapBody: viewModel.unfocus,
            keyboardToolbar: {
                if focus != nil {
                    DToolbar(
                        upAccessibilityLabel: l10n[
                            .buttonBack,
                        ],
                        downAccessibilityLabel: l10n[
                            .buttonNext,
                        ],
                        doneAccessibilityLabel: l10n[
                            .buttonDone,
                        ],
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
                        DText(
                            l10n[
                                .readyMadeTemplateListErrorTitle,
                            ],
                        )
                        .dStyle(
                            font: typography.linkLarge,
                        )

                        DText(
                            l10n[
                                .readyMadeTemplateListErrorDescription,
                            ],
                        )
                        .dStyle(
                            font: typography.linkSmall,
                            color: color.grayscalePlacehold,
                        )
                        .multilineTextAlignment(
                            .center,
                        )

                        DButton(
                            title: l10n[
                                .readyMadeTemplateListRetryButton,
                            ],
                            action: viewModel.onTapRetry,
                        )
                        .dStyle(
                            .primaryButton,
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
                case _ as ReadyMadeTemplateListContentState:
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
            guard viewModel.focus != newValue else { return }
            viewModel.onFocusChanged(
                newValue,
            )
        }
        .onChange(
            of: viewModel.focus,
            initial: true,
        ) { _, newValue in
            guard focus != newValue else { return }
            focus = newValue
        }
        .environmentObject(
            viewModel,
        )
    }
}
