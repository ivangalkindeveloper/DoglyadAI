import DoglyadUI
import SwiftUI

struct PaywallLoadingView: DViewProtocol {
    @EnvironmentObject var theme: DTheme

    var body: some View {
        DShimmerPlaceholder().frame(
            height: size.s48,
        )

        DShimmerPlaceholder().frame(
            height: size.s24,
        )

        VStack(
            spacing: size.s8,
        ) {
            ForEach(
                0 ..< 4,
                id: \.self,
            ) { _ in
                DShimmerPlaceholder().frame(
                    height: size.s56,
                )
            }
        }
        .padding(
            .bottom,
            size.s8,
        )
    }
}
