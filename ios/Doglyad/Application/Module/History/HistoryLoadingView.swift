import DoglyadUI
import SwiftUI

struct HistoryLoadingView: DViewProtocol {
    @EnvironmentObject var theme: DTheme

    let cardCount: Int

    var body: some View {
        VStack(
            spacing: size.s4,
        ) {
            ForEach(
                0 ..< cardCount,
                id: \.self,
            ) { _ in
                HistoryLoadingCardView()
            }
        }
    }
}
