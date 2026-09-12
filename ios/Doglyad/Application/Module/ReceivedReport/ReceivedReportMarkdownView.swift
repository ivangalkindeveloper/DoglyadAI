import DoglyadUI
import SwiftUI

struct ReceivedReportMarkdownView: View {
    @ObservedObject var viewModel: ReceivedReportMarkdownViewModel
    let textColor: Color

    var body: some View {
        DMarkdown(
            content: viewModel.displayedResponse,
            textColor: textColor
        )
        .task {
            await viewModel.animateResponse()
        }
    }
}
