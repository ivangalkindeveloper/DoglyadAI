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
            if !state.selectedFieldIds.isEmpty {
                DButton(
                    title: l10n[
                        .scanSpeechProposalApplyButton,
                    ],
                    action: viewModel.onTapApplySelected,
                )
                .dStyle(
                    .primaryButton,
                )
            }

            DButton(
                title: l10n[
                    .scanSpeechProposalBackButton,
                ],
                action: viewModel.onTapBackToTranscript,
            )
            .dStyle(
                .textWeak,
            )
        }
        .padding(
            size.s16,
        )
    }
}
