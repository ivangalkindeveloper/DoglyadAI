import DoglyadUI
import SwiftUI

struct ScanSpeechBottomSheetView: DView {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: ScanSpeechViewModel

    var body: some View {
        DBottomSheet(
            type: viewModel.isReviewVisible ? .default : .blur,
            title: l10n[
                .scanSpeechTitle,
            ],
            fraction: viewModel.isReviewVisible ? 0.85 : 0.5,
        ) { toolbarHeight, _ in
            Group {
                if viewModel.isProposalVisible {
                    ScanSpeechProposalView()
                } else if viewModel.isReviewVisible {
                    ScanSpeechReviewView()
                } else if !viewModel.isModelReady {
                    ScanSpeechModelPreparationView()
                } else {
                    ScanSpeechRecordingView()
                }
            }
            .padding(
                .top,
                toolbarHeight,
            )
        }
        .animation(
            theme.animation,
            value: viewModel.speechController.status,
        )
        .animation(
            theme.animation,
            value: viewModel.isReviewVisible,
        )
        .animation(
            theme.animation,
            value: viewModel.isModelReady,
        )
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
