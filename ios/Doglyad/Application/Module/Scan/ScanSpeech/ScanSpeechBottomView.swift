import DoglyadUI
import SwiftUI

struct ScanSpeechBottomView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: ScanSpeechViewModel

    var body: some View {
        switch viewModel.state {
        case _ as ScanSpeechReadyState, _ as ScanSpeechPreparingRecordingState, _ as ScanSpeechRecordingState, _ as ScanSpeechTranscribingState, _ as ScanSpeechAutomaticParsingState:
            ScanSpeechRecordingBottomView()
        case _ as ScanSpeechReviewTranscriptState, _ as ScanSpeechReviewParsingState:
            ScanSpeechReviewTranscriptBottomView()
        case let state as ScanSpeechReviewProposalState:
            ScanSpeechReviewProposalBottomView(
                state: state,
            )
        default: EmptyView()
        }
    }
}
