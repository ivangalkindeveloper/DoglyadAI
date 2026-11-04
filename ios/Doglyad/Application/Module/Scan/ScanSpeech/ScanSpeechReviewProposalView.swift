import DoglyadUI
import SwiftUI

struct ScanSpeechReviewProposalView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: ScanSpeechViewModel

    let state: ScanSpeechReviewProposalState
    let toolbarHeight: CGFloat
    let bottomHeight: CGFloat

    var body: some View {
        DScrollVStack(
            spacing: size.s4,
            padding: EdgeInsets(
                top: size.s16 + toolbarHeight,
                leading: size.s16,
                bottom: size.s16 + bottomHeight,
                trailing: size.s16,
            ),
        ) {
            if state.reviewProposals.isEmpty {
                DText(
                    l10n[
                        .scanSpeechProposalNoFieldsDescription,
                    ],
                )
                .dStyle(
                    font: typography.textSmall,
                    color: color.grayscaleBackgroundWeak,
                )
                .padding(
                    .bottom,
                    size.s8,
                )
            } else {
                DText(
                    viewModel.proposalInstructions,
                )
                .dStyle(
                    font: typography.textSmall,
                    color: color.grayscaleBackgroundWeak,
                )
                .padding(
                    .bottom,
                    size.s8,
                )

                ForEach(
                    state.reviewProposals,
                ) { field in
                    ScanSpeechProposalCardView(
                        state: state,
                        proposal: field,
                    )
                }
            }
        }
    }
}
