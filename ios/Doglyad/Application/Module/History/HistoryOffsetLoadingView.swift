import DoglyadUI
import SwiftUI

struct HistoryOffsetLoadingView: View {
    @EnvironmentObject private var theme: DTheme
    private var size: DSize { theme.size }

    private let cardCount = 3

    var body: some View {
        VStack(spacing: size.s4) {
            ForEach(0 ..< cardCount, id: \.self) { _ in
                HistoryLoadingCardView()
            }
        }
    }
}
