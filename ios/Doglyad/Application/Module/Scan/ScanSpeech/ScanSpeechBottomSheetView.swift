import DoglyadUI
import SwiftUI

struct ScanSpeechBottomSheetView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: ScanSpeechViewModel

    var body: some View {
        let fraction: CGFloat = switch viewModel.state {
        case _ as ScanSpeechReviewTranscriptState, _ as ScanSpeechReviewParsingState, _ as ScanSpeechReviewProposalState: 0.9
        default: 0.5
        }

        DBottomSheet(
            type: .blur,
            title: l10n[
                .scanSpeechTitle,
            ],
            fraction: fraction,
        ) { toolbarHeight, bottomHeight in
            ScanSpeechContentStateView(
                toolbarHeight: toolbarHeight,
                bottomHeight: bottomHeight,
            )
        } bottom: {
            ScanSpeechBottomView()
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
