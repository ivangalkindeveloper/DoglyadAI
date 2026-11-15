import DoglyadUI
import SwiftUI

struct ScanSpeechBottomSheetView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: ScanSpeechViewModel
    @FocusState private var isTranscriptFocused: Bool?

    init(
        viewModel: @autoclosure @escaping () -> ScanSpeechViewModel,
    ) {
        _viewModel = StateObject(
            wrappedValue: viewModel(),
        )
    }

    var body: some View {
        let fraction: CGFloat = switch viewModel.state {
        case _ as ScanSpeechReviewTranscriptState, _ as ScanSpeechReviewParsingLoadingState, _ as ScanSpeechReviewProposalState: 0.9
        default: 0.5
        }

        VStack(
            spacing: .zero,
        ) {
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
                    isTranscriptFocused: $isTranscriptFocused,
                )
            } bottom: {
                ScanSpeechBottomView()
            }

            if isTranscriptFocused != nil {
                DToolbar(
                    onTapDone: {
                        isTranscriptFocused = nil
                    },
                )
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
