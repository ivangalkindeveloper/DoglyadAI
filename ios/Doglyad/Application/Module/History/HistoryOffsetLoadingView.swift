import DoglyadUI
import SwiftUI

struct HistoryOffsetLoadingView: DView {
    @EnvironmentObject var theme: DTheme

    private let cardCount = 3

    var body: some View {
        VStack(spacing: size.s4) {
            ForEach(0 ..< cardCount, id: \.self) { _ in
                HistoryLoadingCardView()
            }
        }
    }
}
