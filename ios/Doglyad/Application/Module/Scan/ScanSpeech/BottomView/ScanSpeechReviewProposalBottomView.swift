import DoglyadUI
import SwiftUI

struct ScanSpeechReviewProposalBottomView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: ScanSpeechViewModel
    @EnvironmentObject var theme: DTheme

    let state: ScanSpeechReviewProposalState

    var body: some View {
        VStack(
            spacing: size.s16,
        ) {
            DButton(
                title: l10n[
                    .scanSpeechProposalApplyButton,
                ],
                action: viewModel.onTapApplySelected,
                isDisabled: state.selectedFieldIds.isEmpty,
            )
            .dStyle(
                .primaryButton,
            )

            DButton(
                title: l10n[
                    .scanSpeechProposalBackButton,
                ],
                action: viewModel.onTapBackToTranscript,
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
