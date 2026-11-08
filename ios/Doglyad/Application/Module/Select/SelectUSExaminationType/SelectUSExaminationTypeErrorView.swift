import DoglyadUI
import SwiftUI

struct SelectUSExaminationTypeErrorView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: SelectUSExaminationTypeViewModel

    var body: some View {
        switch viewModel.state {
        case _ as SelectUSExaminationTypeFailedState:
            VStack(
                spacing: size.s16,
            ) {
                DText(
                    l10n[
                        .errorUnknownDescription,
                    ],
                )
                .dStyle(
                    font: typography.textSmall,
                    color: color.grayscalePlacehold,
                    alignment: .center,
                )

                DButton(
                    title: l10n[
                        .buttonUpdate,
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
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
            )
        default: EmptyView()
        }
    }
}
