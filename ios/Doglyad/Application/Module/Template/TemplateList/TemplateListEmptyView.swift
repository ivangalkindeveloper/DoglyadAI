import DoglyadUI
import SwiftUI

struct TemplateListEmptyView: DView {
    @EnvironmentObject var theme: DTheme

    var body: some View {
        VStack(
            spacing: .zero
        ) {
            Image(.doglyadFile)
                .resizable()
                .scaledToFit()
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .center
                )
                .padding(.horizontal, size.s64)

            DText(.templateListEmptyDescription)
                .dStyle(
                    font: typography.textSmall,
                    color: color.grayscalePlacehold,
                    alignment: .center
                )
        }
        .padding(.top, size.screenHeight / 6)
    }
}
