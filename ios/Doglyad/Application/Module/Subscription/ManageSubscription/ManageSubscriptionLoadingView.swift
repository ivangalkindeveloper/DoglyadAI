import DoglyadUI
import SwiftUI

struct ManageSubscriptionLoadingView: DViewProtocol {
    @EnvironmentObject var theme: DTheme

    var body: some View {
        DShimmerPlaceholder().frame(
            height: size.s128 * 2,
        )
        VStack(
            spacing: size.s8,
        ) {
            ForEach(
                0 ..< 3,
                id: \.self,
            ) { _ in DShimmerPlaceholder().frame(
                height: size.s64,
            ) }
        }
    }
}
