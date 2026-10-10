import DoglyadUI
import SwiftUI

struct ScanSpeechProposalView: DView {
    @EnvironmentObject var theme: DTheme
    @ObservedObject var viewModel: ScanSpeechViewModel

    var body: some View {
        VStack(
            spacing: size.s16,
        ) {
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
                        color: color.grayscaleHeader,
                    )

                    if let proposal = viewModel.dictationProposal {
                        if viewModel.reviewProposals.isEmpty,
                           proposal.rejectedFieldIds.isEmpty,
                           proposal.unmappedFindings.isEmpty
                        {
                            DText(
                                .speechProposalNoFields,
                            )
                            .dStyle(
                                font: typography.textSmall,
                                color: color.grayscalePlacehold,
                            )
                        }

                        ForEach(
                            viewModel.reviewProposals,
                        ) { field in
                            ScanSpeechProposalCardView(
                                viewModel: viewModel,
                                proposal: field,
                            )
                        }

                        if !proposal.rejectedFieldIds.isEmpty {
                            DText(
                                .speechProposalRejectedTitle,
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
                                    color: color.grayscaleHeader,
                                )
                            }
                        }

                        if !proposal.unmappedFindings.isEmpty {
                            DText(
                                .speechProposalUnmappedTitle,
                            )
                            .dStyle(
                                font: typography.linkSmall,
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
                                    color: color.grayscaleHeader,
                                )
                            }
                        }
                    }
                }
            }

            DButton(
                title: .speechProposalApplyButton,
                action: viewModel.onTapApplySelected,
                isDisabled: viewModel.isApplyDisabled,
            )
            .dStyle(
                .primaryButton,
            )

            DButton(
                title: .speechProposalBackButton,
                action: viewModel.onTapBackToTranscript,
                isDisabled: viewModel.isLoading,
            )
            .dStyle(
                .primaryText,
            )
        }
        .padding(
            size.s16,
        )
    }
}
