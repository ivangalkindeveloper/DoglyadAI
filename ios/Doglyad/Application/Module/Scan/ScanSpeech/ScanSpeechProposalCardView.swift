import DoglyadNeuralModel
import DoglyadUI
import SwiftUI

struct ScanSpeechProposalCardView: DView {
    @EnvironmentObject var theme: DTheme
    @ObservedObject var viewModel: ScanSpeechViewModel
    let proposal: VoiceFieldProposal

    var body: some View {
        DButtonCard(
            backgroundColor: color.warningBackground,
            action: { viewModel.onTapProposal(proposal.id) }
        ) {
            HStack(alignment: .top, spacing: size.s12) {
                Image(systemName: viewModel.isSelected(proposal.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(color.grayscaleHeader)

                VStack(alignment: .leading, spacing: size.s8) {
                    DText(viewModel.fieldTitle(proposal.id))
                        .dStyle(font: typography.linkSmall)

                    DText(viewModel.proposedValue(proposal.value))
                        .dStyle(font: typography.textSmall)

                    if proposal.warnings.isEmpty {
                        DText(.speechProposalNeedsReview)
                            .dStyle(font: typography.textSmall, color: color.warningDefaultStrong)
                    } else {
                        DText(.speechProposalWarningTitle)
                            .dStyle(font: typography.linkSmall, color: color.warningDefaultStrong)
                        ForEach(proposal.warnings, id: \.self) { warning in
                            DText(viewModel.warningText(warning))
                                .dStyle(font: typography.textSmall, color: color.warningDefaultStrong)
                        }
                    }

                    DText(.speechProposalCurrentValueTitle)
                        .dStyle(font: typography.textXSmall, color: color.grayscalePlacehold)
                    DText(viewModel.currentValue(proposal.id))
                        .dStyle(font: typography.textSmall, color: color.grayscaleHeader)

                    DText(.speechProposalSourceTitle)
                        .dStyle(font: typography.textXSmall, color: color.grayscalePlacehold)
                    DText(proposal.sourceQuote)
                        .dStyle(font: typography.textSmall, color: color.grayscaleHeader)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
