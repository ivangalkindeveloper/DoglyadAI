import DoglyadUI
import SwiftUI

struct HistoryLoadingView: DView {
    @EnvironmentObject var theme: DTheme

    let cardCount: Int

    var body: some View {
        VStack(spacing: size.s4) {
            ForEach(0 ..< cardCount, id: \.self) { _ in
                HistoryLoadingCardView()
            }
        }
    }
}
