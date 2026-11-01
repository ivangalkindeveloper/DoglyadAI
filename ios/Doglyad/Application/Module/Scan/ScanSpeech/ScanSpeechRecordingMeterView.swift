import DoglyadUI
import SwiftUI

struct ScanSpeechRecordingMeterView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: ScanSpeechViewModel

    var body: some View {
        switch viewModel.state {
        case _ as ScanSpeechRecordingState:
            if let text = viewModel.speechController?.text {
                DText(
                    text,
                ).dStyle(
                    font: typography.linkSmall,
                    color: color.grayscaleBackgroundWeak,
                    alignment: .center,
                )
                .lineLimit(
                    1,
                ).truncationMode(
                    .head,
                ).clipped().padding(
                    .horizontal,
                    size.s32,
                ).padding(
                    .bottom,
                    size.s8,
                ).transition(
                    .opacity,
                )
            }

            ScanSpeechAudioMeterView().padding(
                .bottom,
                size.s16,
            ).transition(
                .opacity,
            )
        default: EmptyView()
        }
    }
}
