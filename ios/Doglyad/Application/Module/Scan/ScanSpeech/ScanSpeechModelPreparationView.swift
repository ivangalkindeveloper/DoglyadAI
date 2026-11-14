import DoglyadSpeech
import DoglyadUI
import SwiftUI

struct ScanSpeechModelPreparationView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: ScanSpeechViewModel
    let toolbarHeight: CGFloat
    let bottomHeight: CGFloat

    init(
        toolbarHeight: CGFloat,
        bottomHeight: CGFloat,
    ) {
        self.toolbarHeight = toolbarHeight
        self.bottomHeight = bottomHeight
    }

    var body: some View {
        let preparation: DSpeechModelPreparationStatus = switch viewModel.state {
        case let state as ScanSpeechModelLoadingState: state.preparation
        case _ as ScanSpeechModelPreparationErrorState: .failed
        default: .ready
        }

        ScanSpeechModelPreparationStatusView(
            preparation: preparation,
            toolbarHeight: toolbarHeight,
            bottomHeight: bottomHeight,
        )
    }
}
