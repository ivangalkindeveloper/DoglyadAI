import DoglyadUI
import SwiftUI

struct NeuralModelValueRowView: DView {
    @EnvironmentObject var theme: DTheme

    let title: LocalizedStringResource
    let value: String

    var body: some View {
        HStack(
            alignment: .bottom,
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
