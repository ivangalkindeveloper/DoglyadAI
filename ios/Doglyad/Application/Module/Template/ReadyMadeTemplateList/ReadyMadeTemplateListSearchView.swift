import DoglyadUI
import SwiftUI

struct ReadyMadeTemplateListSearchView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: ReadyMadeTemplateListViewModel
    let focus: FocusState<ReadyMadeTemplateListFocus?>.Binding

    init(
        focus: FocusState<ReadyMadeTemplateListFocus?>.Binding,
    ) {
        self.focus = focus
    }

    var body: some View {
        switch viewModel.state {
        case _ as ReadyMadeTemplateListSuccessState:
            DTextField(
                inputTextController: viewModel.searchTextController,
                focus: DTextFieldFocus(
                    value: .search,
                    state: focus,
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
                accessibilityIdentifier: "readyMade.search",
            )

            .padding(
                .top,
                size.s8,
            )
            .padding(
                .horizontal,
                size.s16,
            )
        case _ as ReadyMadeTemplateListLoadingState, _ as ReadyMadeTemplateListErrorState:
            EmptyView()
        default: EmptyView()
        }
    }
}
