import DoglyadUI
import SwiftUI

struct PaywallFeaturesView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    let state: PaywallContentState

    init(
        state: PaywallContentState,
    ) {
        self.state = state
    }

    var body: some View {
        let features = state.selectedTier?.features ?? []

        VStack(
            alignment: .leading,
            spacing: size.s10,
        ) {
            ForEach(
                features.indices,
                id: \.self,
            ) { index in
                HStack(
                    alignment: .top,
                    spacing: size.s8,
                ) {
                    DIcon(
                        .check,
                        color: color.successDefault,
                    )

                    DText(
                        features[
                            index,
                        ],
                    )
                    .dStyle(
                        font: typography.textSmall,
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true,
                    )
                }
            }
        }
        .padding(
            .bottom,
            size.s8,
        )
        .frame(
            maxWidth: .infinity,
            alignment: .leading,
        )
    }
}
