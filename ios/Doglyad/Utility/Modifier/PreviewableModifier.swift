import DoglyadUI
import Router
import SwiftUI

struct PreviewableModifier: ViewModifier {
    @ViewBuilder
    func body(
        content: Content,
    ) -> some View {
        let container = DependencyContainer.previewable
        content
            .environmentObject(
                DRouter(
                    initialRoute: RouteScreen(
                        type: .onBoarding,
                        arguments: nil,
                    ),
                ),
            )
            .dMessage()
            .dThemeWrapper()
            .environmentObject(
                ApplicationRootViewModel(),
            )
            .environmentObject(
                container,
            )
            .localization(
                container.l10n,
            )
            .environmentObject(
                UltrasoundRootViewModel(
                    container: container,
                ),
            )
            .environmentObject(
                SubscriptionRootViewModel(
                    container: container,
                ),
            )
    }
}
