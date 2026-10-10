import SwiftUI
internal import SwiftMessages

private struct DMessageModifier: ViewModifier {
    @EnvironmentObject private var theme: DTheme

    @StateObject var messager = DMessager()

    func body(
        content: Content,
    ) -> some View {
        content
            .swiftMessage(
                message: $messager.message,
            ) { message in
                DMessageCard(
                    theme: theme,
                    message: message,
                )
                .padding(
                    .top,
                    theme.size.s4,
                )
                .padding(
                    .horizontal,
                    theme.size.s16,
                )
            }
            .environmentObject(
                messager,
            )
    }
}

public extension View {
    func dMessage() -> some View {
        modifier(
            DMessageModifier(),
        )
    }
}
