import DoglyadUI
import SwiftUI

struct ScanSpeechRecordingBottomView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: ScanSpeechViewModel
    @EnvironmentObject var theme: DTheme

    var body: some View {
        let icon: ImageResource = switch viewModel.state {
        case _ as ScanSpeechReadyState: .play
        default: .check
        }
        let title = switch viewModel.state {
        case _ as ScanSpeechReadyState: l10n[
                .scanSpeechRecordingStartButton,
            ]
        default: l10n[
                .scanSpeechRecordingParseButton,
            ]
        }
        let isProcessing = switch viewModel.state {
        case _ as ScanSpeechPreparingRecordingState, _ as ScanSpeechTranscribingState, _ as ScanSpeechAutomaticParsingState: true
        default: false
        }

        DButton(
            image: icon,
            title: title,
            action: viewModel.onTapSpeech,
            isLoading: isProcessing,
        )
        .dStyle(
            .primaryButton,
        )
        .padding(
            size.s16,
        )
    }
}
