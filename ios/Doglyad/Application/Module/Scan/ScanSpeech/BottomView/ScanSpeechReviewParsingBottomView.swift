import DoglyadUI
import SwiftUI

struct ScanSpeechReviewParsingBottomView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: ScanSpeechViewModel
    @EnvironmentObject var theme: DTheme

    var body: some View {
        let isProcessing = switch viewModel.state {
        case _ as ScanSpeechReviewParsingState: true
        default: false
        }

        VStack(
            spacing: size.s16,
        ) {
            DButton(
                title: l10n[
                    .scanSpeechReviewContinueButton,
                ],
                action: viewModel.onTapContinue,
                isLoading: isProcessing,
                isDisabled: isProcessing || viewModel.textForParsing == nil,
            )
            .dStyle(
                .primaryButton,
            )

            DButton(
                title: l10n[
                    .scanSpeechReviewRecordAgainButton,
                ],
                action: viewModel.onTapRecordAgain,
                isDisabled: isProcessing,
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
