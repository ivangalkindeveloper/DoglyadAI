import DoglyadUI
import SwiftUI

struct HistoryLoadingView: View {
    @EnvironmentObject private var theme: DTheme
    private var size: DSize { theme.size }

    let cardCount: Int

    var body: some View {
        VStack(spacing: size.s4) {
            ForEach(0 ..< cardCount, id: \.self) { _ in
                HistoryLoadingCardView()
            }
        }
    }
}
