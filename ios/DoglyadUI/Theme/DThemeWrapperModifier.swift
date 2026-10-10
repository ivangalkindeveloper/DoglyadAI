import SwiftUI

private struct DThemeWrapperModifier: ViewModifier {
    @StateObject private var theme = DTheme.light

    func body(
        content: Content,
    ) -> some View {
        content
            .preferredColorScheme(
                .light,
            )
            .environmentObject(
                theme,
            )
    }
}

public extension View {
    func dThemeWrapper() -> some View {
        modifier(
            DThemeWrapperModifier(),
        )
    }
}
