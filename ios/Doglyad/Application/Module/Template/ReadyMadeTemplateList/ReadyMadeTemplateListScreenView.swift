import DoglyadUI
import SwiftUI

struct ReadyMadeTemplateListScreenView: DView {
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: ReadyMadeTemplateListViewModel
    @FocusState private var focus: ReadyMadeTemplateListViewModel.Focus?
    @State private var searchFieldHeight: CGFloat = 0

    var body: some View {
        DScreen(
            title: .readyMadeTemplateListTitle,
            onTapBack: viewModel.onTapBack,
            onTapBody: viewModel.unfocus,
            keyboardToolbar: {
                if focus != nil {
                    DToolbar(
                        upAccessibilityLabel: .buttonBack,
                        downAccessibilityLabel: .buttonNext,
                        doneAccessibilityLabel: .buttonDone,
                        onTapDone: viewModel.unfocus
                    )
                }
            },
            content: { toolbarInset, bottomInset in
                switch viewModel.state {
                case .loading:
                    ProgressView()
                        .tint(color.primaryDefault)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, toolbarInset)
                        .transition(.opacity)
                case .error:
                    VStack(
                        spacing: size.s16
                    ) {
                        DText(.readyMadeTemplateListErrorTitle)
                            .dStyle(
                                font: typography.linkLarge
                            )

                        DText(.readyMadeTemplateListErrorDescription)
                            .dStyle(
                                font: typography.linkSmall,
                                color: color.grayscalePlacehold
                            )
                            .multilineTextAlignment(.center)

                        DButton(
                            title: .readyMadeTemplateListRetryButton,
                            action: viewModel.onTapRetry
                        )
                        .dStyle(.primaryButton)
                    }
                    .padding(size.s16)
                    .padding(.top, toolbarInset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                case .success:
                    ZStack(
                        alignment: .top
                    ) {
                        ScrollView(
                            showsIndicators: false
                        ) {
                            LazyVStack(
                                alignment: .leading,
                                spacing: size.s4
                            ) {
                                if viewModel.filteredTemplates.isEmpty {
                                    DText(viewModel.emptyDescription)
                                        .dStyle(
                                            font: typography.textSmall,
                                            color: color.grayscalePlacehold
                                        )
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                        .transition(.opacity)
                                } else {
                                    ForEach(viewModel.filteredTemplates) { template in
                                        ReadyMadeTemplateListItemCardView(
                                            template: template,
                                            examinationTypeTitle: viewModel.examinationTypeTitle(for: template),
                                            action: {
                                                viewModel.onTapTemplate(template)
                                            }
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, size.s16)
                            .padding(.top, toolbarInset + size.s16 + searchFieldHeight + size.s64)
                            .padding(.bottom, size.s32)
                        }

                        DTextField(
                            controller: viewModel.searchController,
                            focus: DTextFieldFocus(
                                value: .search,
                                state: $focus
                            ),
                            title: .readyMadeTemplateListSearchLabel,
                            placeholder: .readyMadeTemplateListSearchPlaceholder,
                            mode: DTextFieldSingleLineMode(submitLabel: .done),
                            autocapitalization: .never
                        )
                        .background {
                            GeometryReader { proxy in
                                Color.clear
                                    .preference(
                                        key: ReadyMadeTemplateListSearchFieldHeightPreferenceKey.self,
                                        value: proxy.size.height
                                    )
                            }
                        }
                        .onPreferenceChange(ReadyMadeTemplateListSearchFieldHeightPreferenceKey.self) { value in
                            guard searchFieldHeight != value else { return }
                            searchFieldHeight = value
                        }

                        .padding(.top, toolbarInset + size.s8)
                        .padding(.horizontal, size.s16)
                        .padding(.bottom, bottomInset + size.s16)
                    }
                    .transition(.opacity)
                }
            }
        )
        .animation(theme.animation, value: viewModel.state)
        .animation(theme.animation, value: viewModel.filteredTemplates)
        .onAppear(perform: viewModel.onAppear)
        .onSubmit {
            viewModel.unfocus()
        }
        .onChange(of: focus, initial: true) { _, newValue in
            guard viewModel.focus != newValue else { return }
            viewModel.focus = newValue
        }
        .onChange(of: viewModel.focus, initial: true) { _, newValue in
            guard focus != newValue else { return }
            focus = newValue
        }
        .environmentObject(viewModel)
    }
}

private struct ReadyMadeTemplateListSearchFieldHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
