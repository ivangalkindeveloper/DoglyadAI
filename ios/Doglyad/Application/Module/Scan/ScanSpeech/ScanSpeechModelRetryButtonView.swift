import DoglyadSpeech
import DoglyadUI
import SwiftUI

struct ScanSpeechModelRetryButtonView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: ScanSpeechViewModel
    let preparation: DSpeechModelPreparationStatus

    init(
        preparation: DSpeechModelPreparationStatus,
    ) {
        self.preparation = preparation
    }

    var body: some View {
        switch preparation {
        case .failed:
            DButton(
                title: l10n[
                    .scanSpeechModelRetryButton,
                ],
                action: viewModel.onTapRetryModelPreparation,
            ).dStyle(
                .primaryButton,
            )
        case .checking, .downloading, .loading, .ready: EmptyView()
        }
    }
}
