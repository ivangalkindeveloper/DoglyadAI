import DoglyadUI
import SwiftUI

struct ScanSpeechProposalView: DView {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: ScanSpeechViewModel

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
                                l10n[
                                    .scanSpeechProposalNoFieldsDescription,
                                ],
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
                                    color: color.grayscaleHeader,
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
                title: l10n[
                    .scanSpeechProposalApplyButton,
                ],
                action: viewModel.onTapApplySelected,
                isDisabled: viewModel.isApplyDisabled,
            )
            .dStyle(
                .primaryButton,
            )

            DButton(
                title: l10n[
                    .scanSpeechProposalBackButton,
                ],
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
