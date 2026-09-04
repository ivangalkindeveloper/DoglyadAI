import DoglyadUI
import SwiftUI

struct HistoryEmptyView: View {
    @EnvironmentObject private var theme: DTheme
    private var color: DColor { theme.color }
    private var size: DSize { theme.size }
    private var typography: DTypography { theme.typography }

    var body: some View {
        VStack(
            spacing: .zero
        ) {
            Image(.doglyadMagnifier)
                .resizable()
                .scaledToFit()
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .center
                )
                .padding(.horizontal, size.s64)

            DText(.historyEmptyDescription)
                .dStyle(
                    font: typography.textSmall,
                    color: color.grayscalePlacehold,
                    alignment: .center
                )
        }
        .padding(.top, size.screenHeight / 6)
    }
}
