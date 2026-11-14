import DoglyadNeuralModel
import DoglyadUI
import SwiftUI

struct ScanSpeechProposalCardView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: ScanSpeechViewModel
    let state: ScanSpeechReviewProposalState
    let proposal: DNeuralUltrasoundVoiceFieldProposal

    init(
        state: ScanSpeechReviewProposalState,
        proposal: DNeuralUltrasoundVoiceFieldProposal,
    ) {
        self.state = state
        self.proposal = proposal
    }

    var body: some View {
        let isSelected = state.selectedFieldIds.contains(
            proposal.id,
        )
        let warnings = proposal.warnings.isEmpty
            ? [l10n[
                .scanSpeechProposalNeedsReviewLabel,
            ]]
            : proposal.warnings.map {
                viewModel.warningText(
                    $0,
                )
            }

        DTextButton(
            action: {
                viewModel.onTapProposal(
                    proposal.id,
                )
            },
            content: {
                HStack(
                    alignment: .top,
                    spacing: size.s12,
                ) {
                    DCheckbox(
                        isChecked: .constant(
                            isSelected,
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
                            color: color.grayscaleBackgroundWeak,
                        )

                        DText(
                            viewModel.proposedValue(
                                proposal.value,
                            ),
                        )
                        .dStyle(
                            font: typography.textSmall,
                            color: color.grayscaleBackgroundWeak,
                        )

                        VStack(
                            alignment: .leading,
                            spacing: 0,
                        ) {
                            ForEach(
                                warnings.indices,
                                id: \.self,
                            ) { index in
                                HStack(
                                    alignment: .firstTextBaseline,
                                    spacing: size.s8,
                                ) {
                                    DText(
                                        "•",
                                    )
                                    .dStyle(
                                        font: typography.textSmall,
                                        color: color.warningDefaultStrong,
                                    )

                                    DText(
                                        warnings[
                                            index,
                                        ],
                                    )
                                    .dStyle(
                                        font: typography.textSmall,
                                        color: color.warningDefaultStrong,
                                    )
                                }
                            }
                        }

                        VStack(
                            alignment: .leading,
                            spacing: 0,
                        ) {
                            DText(
                                l10n[
                                    .scanSpeechProposalSourceTitle,
                                ],
                            )
                            .dStyle(
                                font: typography.textXSmall,
                                color: color.grayscaleBackgroundWeak,
                            )

                            DText(
                                proposal.sourceQuote,
                            )
                            .dStyle(
                                font: typography.textSmall,
                                color: color.grayscaleBackgroundWeak,
                            )
                        }
                    }
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading,
                    )
                }
                .padding(
                    size.s16,
                )
                .background(
                    DCardBackground(
                        cornerRadius: size.cardCornerRadius,
                        color: color.grayscaleHeader,
                    ),
                )
            },
            accessibilityIdentifier: "scanSpeech.proposal.\(proposal.id.rawValue).selected.\(isSelected)",
        )
    }
}
