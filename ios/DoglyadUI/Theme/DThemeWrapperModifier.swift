import SwiftUI

struct DThemeWrapperModifier: ViewModifier {
    @StateObject private var theme = DTheme.light

    init() {}

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
