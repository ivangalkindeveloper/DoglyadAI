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
                Image(
                    systemName: viewModel.isSelected(
                        proposal.id,
                    ) ? "checkmark.circle.fill" : "circle",
                )
                .foregroundStyle(
                    color.grayscaleHeader,
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
                                .speechProposalNeedsReview,
                            ],
                        )
                        .dStyle(
                            font: typography.textSmall,
                            color: color.warningDefaultStrong,
                        )
                    } else {
                        DText(
                            l10n[
                                .speechProposalWarningTitle,
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
                            .speechProposalCurrentValueTitle,
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
                            .speechProposalSourceTitle,
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
