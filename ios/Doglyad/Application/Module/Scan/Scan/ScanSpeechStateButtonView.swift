import DoglyadUI
import SwiftUI

struct ScanSpeechStateButtonView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: ScanViewModel
    @EnvironmentObject private var l10n: L10N

    var body: some View {
        switch viewModel.state {
        case _ as ScanGenerationLoadingState: EmptyView()
        default:
            DButton(
                image: .microphone,
                title: l10n[
                    .buttonSpeech,
                ],
                action: viewModel.onTapSpeech,
                accessibilityIdentifier: "scan.speech",
            )
            .dStyle(
                .primaryChip,
            )

            .paidBadge(
                viewModel.subscriptionAvailability(
                    of: .formCompletionViaMicrophone,
                ),
            )
            .padding(
                .bottom,
                size.s8,
            )
            .transition(
                .move(
                    edge: .bottom,
                ),
            )
        }
    }
}
