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
        let proposal = state.proposal

        ScrollView {
            VStack(
                alignment: .leading,
                spacing: size.s12,
            ) {
                DText(
                    viewModel.proposalInstructions,
                )
                .dStyle(
                    font: typography.textSmall,
                    color: color.grayscaleBackgroundWeak,
                )

                if state.reviewProposals.isEmpty,
                   proposal.rejectedFieldIds.isEmpty,
                   proposal.unmappedFindings.isEmpty
                {
                    DText(
                        l10n[
                            .scanSpeechProposalNoFieldsDescription,
                        ],
                    )
                    .dStyle(
                        font: typography.textSmall,
                        color: color.grayscaleBackgroundWeak,
                    )
                }

                ForEach(
                    state.reviewProposals,
                ) { field in
                    ScanSpeechProposalCardView(
                        state: state,
                        proposal: field,
                    )
                }

                if !proposal.rejectedFieldIds.isEmpty {
                    DText(
                        l10n[
                            .scanSpeechProposalRejectedTitle,
                        ],
                    )
                    .dStyle(
                        font: typography.linkSmall,
                        color: color.warningDefaultStrong,
                    )
                    ForEach(
                        proposal.rejectedFieldIds,
                        id: \.self,
                    ) { fieldId in
                        DText(
                            viewModel.fieldTitle(
                                fieldId,
                            ),
                        )
                        .dStyle(
                            font: typography.textSmall,
                            color: color.grayscaleBackgroundWeak,
                        )
                    }
                }

                if !proposal.unmappedFindings.isEmpty {
                    DText(
                        l10n[
                            .scanSpeechProposalUnmappedTitle,
                        ],
                    )
                    .dStyle(
                        font: typography.linkSmall,
                        color: color.grayscaleBackgroundWeak,
                    )
                    ForEach(
                        proposal.unmappedFindings,
                        id: \.self,
                    ) { finding in
                        DText(
                            finding,
                        )
                        .dStyle(
                            font: typography.textSmall,
                            color: color.grayscaleBackgroundWeak,
                        )
                    }
                }
            }
            .padding(
                .horizontal,
                size.s16,
            )
            .padding(
                .top,
                toolbarHeight + size.s16,
            )
            .padding(
                .bottom,
                max(
                    .zero,
                    bottomHeight,
                ) + size.s16,
            )
        }
    }
}
