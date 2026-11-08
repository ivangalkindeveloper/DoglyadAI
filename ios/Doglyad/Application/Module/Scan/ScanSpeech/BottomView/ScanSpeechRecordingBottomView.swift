import DoglyadUI
import SwiftUI

struct ScanSpeechRecordingBottomView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: ScanSpeechViewModel
    @EnvironmentObject var theme: DTheme

    var body: some View {
        let (icon, title, isProcessing): (ImageResource, LocalizedStringResource, Bool) = switch viewModel.state {
        case _ as ScanSpeechReadyState:
            (.play, l10n[
                .scanSpeechRecordingStartButton,
            ], false)
        case _ as ScanSpeechRecordingPreparationLoadingState, _ as ScanSpeechTranscriptionLoadingState, _ as ScanSpeechAutomaticParsingLoadingState:
            (.check, l10n[
                .scanSpeechRecordingParseButton,
            ], true)
        default:
            (.check, l10n[
                .scanSpeechRecordingParseButton,
            ], false)
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
