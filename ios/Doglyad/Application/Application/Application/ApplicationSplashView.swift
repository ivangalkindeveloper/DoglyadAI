import DoglyadUI
import SwiftUI

struct ApplicationSplashView: DViewProtocol {
    @EnvironmentObject var theme: DTheme

    var body: some View {
        color.grayscaleBackground.overlay {
            DImage(
                .splash,
            ).scaledToFill()
        }.ignoresSafeArea()
    }
}
