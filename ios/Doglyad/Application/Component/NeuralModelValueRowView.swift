import DoglyadUI
import SwiftUI

struct NeuralModelValueRowView: View {
    @EnvironmentObject private var theme: DTheme
    private var color: DColor { theme.color }
    private var size: DSize { theme.size }
    private var typography: DTypography { theme.typography }

    let title: LocalizedStringResource
    let value: String

    var body: some View {
        HStack(
            alignment: .top,
            spacing: size.s4
        ) {
            DText(title)
                .dStyle(
                    font: typography.textXSmall,
                    color: color.grayscalePlacehold
                )

            DText(value)
                .dStyle(
                    font: typography.linkSmall
                )
                .lineLimit(2)
        }
    }
}
