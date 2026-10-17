import DoglyadUI
import SwiftUI

struct ReportReceivedMarkdownView: View {
    @EnvironmentObject private var viewModel: ReportReceivedViewModel
    let textColor: Color

    var body: some View {
        DMarkdown(
            content: viewModel.responseText,
            textColor: textColor,
        )
        .task {
            await viewModel.animateResponse()
        }
    }
}
