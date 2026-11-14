import DoglyadUI
import SwiftUI

struct ReportReceivedMarkdownView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: ReportReceivedViewModel

    init() {}

    var body: some View {
        if viewModel.isWaitingForFirstToken {
            ReportReceivedLoadingView()
        } else {
            DStreamingMarkdown(
                streamID: viewModel.actualModelReport.id,
                content: viewModel.displayedMarkdownText,
                isStreaming: viewModel.isGenerating,
                textColor: color.grayscaleBackgroundWeak,
            )
            .dShimmer(
                isShimmering: viewModel.isGenerating,
                cornerRadius: 0,
                masksContent: true,
            )
        }
    }
}
