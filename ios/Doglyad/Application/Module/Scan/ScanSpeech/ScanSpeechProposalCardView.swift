import DoglyadNeuralModel
import DoglyadUI
import SwiftUI

struct ScanSpeechProposalCardView: DView {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: ScanSpeechViewModel
    let proposal: DNeuralUltrasoundVoiceFieldProposal

    var body: some View {
        DButtonCard(
            backgroundColor: color.warningBackground,
            action: { viewModel.onTapProposal(
                proposal.id,
            ) },
        ) {
            HStack(
                alignment: .top,
                spacing: size.s12,
            ) {
                DCheckbox(
                    isChecked: .constant(
                        viewModel.isSelected(
                            proposal.id,
                        ),
                    ),
                )
                .allowsHitTesting(
                    false,
                )

                VStack(
                    alignment: .leading,
                    spacing: size.s8,
                ) {
                    DText(
                        viewModel.fieldTitle(
                            proposal.id,
                        ),
                    )
                    .dStyle(
                        font: typography.linkSmall,
                    )

                    DText(
                        viewModel.proposedValue(
                            proposal.value,
                        ),
                    )
                    .dStyle(
                        font: typography.textSmall,
                    )

                    if proposal.warnings.isEmpty {
                        DText(
                            l10n[
                                .scanSpeechProposalNeedsReviewLabel,
                            ],
                        )
                        .dStyle(
                            font: typography.textSmall,
                            color: color.warningDefaultStrong,
                        )
                    } else {
                        DText(
                            l10n[
                                .scanSpeechProposalWarningTitle,
                            ],
                        )
                        .dStyle(
                            font: typography.linkSmall,
                            color: color.warningDefaultStrong,
                        )
                        ForEach(
                            proposal.warnings,
                            id: \.self,
                        ) { warning in
                            DText(
                                viewModel.warningText(
                                    warning,
                                ),
                            )
                            .dStyle(
                                font: typography.textSmall,
                                color: color.warningDefaultStrong,
                            )
                        }
                    }

                    DText(
                        l10n[
                            .scanSpeechProposalCurrentValueTitle,
                        ],
                    )
                    .dStyle(
                        font: typography.textXSmall,
                        color: color.grayscalePlacehold,
                    )
                    DText(
                        viewModel.currentValue(
                            proposal.id,
                        ),
                    )
                    .dStyle(
                        font: typography.textSmall,
                        color: color.grayscaleHeader,
                    )

                    DText(
                        l10n[
                            .scanSpeechProposalSourceTitle,
                        ],
                    )
                    .dStyle(
                        font: typography.textXSmall,
                        color: color.grayscalePlacehold,
                    )
                    DText(
                        proposal.sourceQuote,
                    )
                    .dStyle(
                        font: typography.textSmall,
                        color: color.grayscaleHeader,
                    )
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading,
                )
            }
        }
    }
}
