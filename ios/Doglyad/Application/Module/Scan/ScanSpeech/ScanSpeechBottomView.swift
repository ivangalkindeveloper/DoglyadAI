import DoglyadUI
import SwiftUI

struct ScanSpeechBottomView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: ScanSpeechViewModel

    var body: some View {
        switch viewModel.state {
        case _ as ScanSpeechReadyState, _ as ScanSpeechRecordingPreparationLoadingState, _ as ScanSpeechRecordingState, _ as ScanSpeechTranscriptionLoadingState, _ as ScanSpeechAutomaticParsingLoadingState:
            ScanSpeechRecordingBottomView()
        case _ as ScanSpeechReviewTranscriptState, _ as ScanSpeechReviewParsingLoadingState:
            ScanSpeechReviewTranscriptBottomView()
        case let state as ScanSpeechReviewProposalState:
            ScanSpeechReviewProposalBottomView(
                state: state,
            )
        default: EmptyView()
        }
    }
}
