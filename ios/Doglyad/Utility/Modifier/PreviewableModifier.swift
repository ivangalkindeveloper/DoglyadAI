import DoglyadUI
import Router
import SwiftUI

private struct PreviewableModifier: ViewModifier {
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
                ApplicationViewModel(),
            )
            .environmentObject(
                container,
            )
            .environmentObject(
                UltrasoundViewModel(
                    container: container,
                ),
            )
            .environmentObject(
                SubscriptionViewModel(
                    container: container,
                ),
            )
    }
}

extension View {
    func previewable() -> some View {
        modifier(
            PreviewableModifier(),
        )
    }
}
