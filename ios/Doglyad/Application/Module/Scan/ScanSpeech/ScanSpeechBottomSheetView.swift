import DoglyadUI
import SwiftUI

struct ScanSpeechBottomSheetView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: ScanSpeechViewModel

    var body: some View {
        let fraction: CGFloat = switch viewModel.state {
        case _ as ScanSpeechTranscriptReviewState, _ as ScanSpeechReviewParsingState, _ as ScanSpeechReviewProposalState: 0.9
        default: 0.5
        }
        DBottomSheet(
            type: .blur,
            title: l10n[
                .scanSpeechTitle,
            ],
            fraction: fraction,
        ) { toolbarHeight, bottomHeight in
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
            case _ as ScanSpeechTranscriptReviewState, _ as ScanSpeechReviewParsingState:
                ScanSpeechReviewParsingView(
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
        } bottom: {
            switch viewModel.state {
            case _ as ScanSpeechTranscriptReviewState, _ as ScanSpeechReviewParsingState:
                ScanSpeechReviewParsingBottomView()
            case let state as ScanSpeechReviewProposalState:
                ScanSpeechReviewProposalBottomView(
                    state: state,
                )
            default: EmptyView()
            }
        }
        .onAppear(
            perform: viewModel.onAppear,
        )
        .onDisappear(
            perform: viewModel.onDisappear,
        )
        .environmentObject(
            viewModel,
        )
    }
}
