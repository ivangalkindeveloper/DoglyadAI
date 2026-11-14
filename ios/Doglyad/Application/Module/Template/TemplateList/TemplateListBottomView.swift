import DoglyadUI
import SwiftUI

struct TemplateListBottomView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: TemplateListViewModel

    init() {}

    var body: some View {
        let (title, action): (L10NKey?, () -> Void) = switch viewModel.state {
        case _ as TemplateListErrorState: (.buttonUpdate, viewModel.onTapRetry)
        default: (.templateListAddButton, viewModel.onTapAdd)
        }

        if let title {
            DButton(
                title: l10n[
                    title,
                ],
                action: action,
            )
            .dStyle(
                .primaryButton,
            )
            .padding(
                size.s16,
            )
        }
    }
}
