import DoglyadUI
import SwiftUI

struct TemplateListLoadingView: DView {
    @EnvironmentObject var theme: DTheme

    private let cardCount = 5

    var body: some View {
        VStack(spacing: size.s4) {
            ForEach(0 ..< cardCount, id: \.self) { _ in
                TemplateListLoadingCardView()
            }
        }
    }
}
