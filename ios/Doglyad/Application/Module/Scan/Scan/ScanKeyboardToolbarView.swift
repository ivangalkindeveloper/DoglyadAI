import DoglyadUI
import SwiftUI

struct ScanKeyboardToolbarView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: ScanViewModel
    let isProcessing: Bool

    init(
        isProcessing: Bool,
    ) {
        self.isProcessing = isProcessing
    }

    var body: some View {
        let speechToolbarButton: DToolbarButton? = switch viewModel.subscriptionAvailability(
            of: .formCompletionViaMicrophone,
        ) {
        case .available, .offered:
            DToolbarButton(
                style: .primaryDefault,
                badge: viewModel.speechButtonBadge,
                content: .icon(
                    .microphone,
                ),
                action: viewModel.onTapSpeech,
            )
        case .unavailable: nil
        }

        DToolbar(
            onTapUp: viewModel.isPreviousFieldFocusable ? {
                viewModel.onTapToolbarUp()
            } : nil,
            onTapDown: viewModel.isNextFieldFocusable ? {
                viewModel.onTapToolbarDown()
            } : nil,
            onTapDone: viewModel.unfocus,
            trailButtons: [speechToolbarButton, DToolbarButton(
                style: .primaryDefault,
                content: .text(
                    l10n[
                        .buttonGenerate,
                    ],
                ),
                action: viewModel.onTapScan,
                isDisabled:
                isProcessing,
            )].compactMap(
                \.self,
            ),
            isDisabled:
            isProcessing,
        )
    }
}
