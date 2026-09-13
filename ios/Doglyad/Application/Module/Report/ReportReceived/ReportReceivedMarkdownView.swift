import DoglyadUI
import SwiftUI

struct ReportReceivedMarkdownView: View {
    @ObservedObject var viewModel: ReportReceivedMarkdownViewModel
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
