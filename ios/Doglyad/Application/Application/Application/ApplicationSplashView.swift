import DoglyadUI
import SwiftUI

struct ApplicationSplashView: DViewProtocol {
    @EnvironmentObject var theme: DTheme

    init() {}

    var body: some View {
        color.grayscaleBackground.overlay {
            Image(
                .splash,
            )
            .resizable()
            .scaledToFill()
        }.ignoresSafeArea()
            .accessibilityElement(
                children: .ignore,
            )
            .accessibilityIdentifier(
                "application.splash",
            )
    }
}
