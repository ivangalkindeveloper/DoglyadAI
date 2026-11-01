import DoglyadUI
import SwiftUI

struct ShareSendingIconView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: ShareViewModel

    var body: some View {
        switch viewModel.state {
        case _ as ShareSendingState:
            DShimmerPlaceholder().frame(
                width: size.s64,
                height: size.s8,
            )
            .transition(
                .opacity,
            )
        default:
            DIcon(
                .send,
                color: color.grayscaleHeader,
            )
            .transition(
                .opacity,
            )
        }
    }
}
