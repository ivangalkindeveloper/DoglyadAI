import DoglyadUI
import SwiftUI

struct RecievedConclusionMarkdownView: View {
    @ObservedObject var viewModel: RecievedConclusionMarkdownViewModel
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
