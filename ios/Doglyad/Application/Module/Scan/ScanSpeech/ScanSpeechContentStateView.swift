import DoglyadUI
import SwiftUI

struct ScanSpeechContentStateView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: ScanSpeechViewModel
    let toolbarHeight: CGFloat
    let bottomHeight: CGFloat
    let transcriptFocus: FocusState<Bool?>.Binding

    var body: some View {
        switch viewModel.state {
        case _ as ScanSpeechModelLoadingState, _ as ScanSpeechModelPreparationFailedState:
            ScanSpeechModelPreparationView(
                toolbarHeight: toolbarHeight,
                bottomHeight: bottomHeight,
            )
        case _ as ScanSpeechReadyState, _ as ScanSpeechRecordingPreparationLoadingState, _ as ScanSpeechRecordingState, _ as ScanSpeechTranscriptionLoadingState, _ as ScanSpeechAutomaticParsingLoadingState:
            ScanSpeechRecordingView(
                toolbarHeight: toolbarHeight,
                bottomHeight: bottomHeight,
            )
        case _ as ScanSpeechReviewTranscriptState, _ as ScanSpeechReviewParsingLoadingState:
            ScanSpeechReviewTranscriptView(
                transcriptFocus: transcriptFocus,
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
