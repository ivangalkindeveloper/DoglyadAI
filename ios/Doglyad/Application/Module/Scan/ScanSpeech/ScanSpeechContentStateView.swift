import DoglyadUI
import SwiftUI

struct ScanSpeechContentStateView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: ScanSpeechViewModel
    let toolbarHeight: CGFloat
    let bottomHeight: CGFloat

    var body: some View {
        switch viewModel.state {
        case _ as ScanSpeechPreparingModelState, _ as ScanSpeechModelPreparationFailedState:
            ScanSpeechModelPreparationView(
                toolbarHeight: toolbarHeight,
                bottomHeight: bottomHeight,
            )
        case _ as ScanSpeechReadyState, _ as ScanSpeechPreparingRecordingState, _ as ScanSpeechRecordingState, _ as ScanSpeechTranscribingState, _ as ScanSpeechAutomaticParsingState:
            ScanSpeechRecordingView(
                toolbarHeight: toolbarHeight,
                bottomHeight: bottomHeight,
            )
        case _ as ScanSpeechReviewTranscriptState, _ as ScanSpeechReviewParsingState:
            ScanSpeechReviewTranscriptView(
                toolbarHeight: toolbarHeight,
                bottomHeight: bottomHeight,
            )
        case let state as ScanSpeechReviewProposalState:
            ScanSpeechReviewProposalView(
                state: state,
                toolbarHeight: toolbarHeight,
                bottomHeight: bottomHeight,
            )
        default: EmptyView()
        }
    }
}
