import DoglyadUI
import SwiftUI

struct ScanSpeechTranscriptionErrorBottomView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: ScanSpeechViewModel

    init() {}

    var body: some View {
        VStack(
            spacing: size.s16,
        ) {
            DButton(
                title: l10n[
                    .buttonRetry,
                ],
                action: viewModel.onTapRetryTranscription,
            )
            .dStyle(
                .primaryButton,
            )

            DButton(
                title: l10n[
                    .scanSpeechReviewRecordAgainButton,
                ],
                action: viewModel.onTapRecordAgain,
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
