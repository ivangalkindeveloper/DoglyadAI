import DoglyadUI
import SwiftUI

struct ScanSpeechBottomSheetView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: ScanSpeechViewModel

    var body: some View {
        let sheetType: DBottomSheetType = switch viewModel.state {
        case _ as ScanSpeechTranscriptReviewState, _ as ScanSpeechReviewParsingState, _ as ScanSpeechProposalReviewState: .default
        default: .blur
        }
        let fraction: CGFloat = switch viewModel.state {
        case _ as ScanSpeechTranscriptReviewState, _ as ScanSpeechReviewParsingState, _ as ScanSpeechProposalReviewState: 0.85
        default: 0.5
        }
        DBottomSheet(
            type: sheetType,
            title: l10n[
                .scanSpeechTitle,
            ],
            fraction: fraction,
        ) { toolbarHeight, _ in
            Group {
                switch viewModel.state {
                case _ as ScanSpeechPreparingModelState, _ as ScanSpeechModelPreparationFailedState:
                    ScanSpeechModelPreparationView()
                case _ as ScanSpeechReadyState, _ as ScanSpeechPreparingRecordingState, _ as ScanSpeechRecordingState, _ as ScanSpeechTranscribingState, _ as ScanSpeechAutomaticParsingState:
                    ScanSpeechRecordingView()
                case _ as ScanSpeechTranscriptReviewState, _ as ScanSpeechReviewParsingState:
                    ScanSpeechReviewView()
                case _ as ScanSpeechProposalReviewState:
                    ScanSpeechProposalView()
                default: DUnexpectedStateView(
                        state: viewModel.state,
                    )
                }
            }.padding(
                .top,
                toolbarHeight,
            )
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
