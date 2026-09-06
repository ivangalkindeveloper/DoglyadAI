import DoglyadUI
import SwiftUI

struct HistoryDayHeaderView: View {
    @EnvironmentObject private var theme: DTheme
    private var color: DColor { theme.color }
    private var size: DSize { theme.size }
    private var typography: DTypography { theme.typography }

    let title: String

    var body: some View {
        HStack(spacing: .zero) {
            DText(title)
                .dStyle(
                    font: typography.linkSmall
                )
                .padding(.horizontal, size.s12)
                .padding(.vertical, size.s8)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )

            Spacer(minLength: .zero)
        }
        .padding(.vertical, size.s4)
        .padding(.bottom, size.s4)
        .frame(maxWidth: .infinity)
    }
}
