import SwiftUI
internal import SwiftMessages

struct DMessageModifier: ViewModifier {
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
                    type: message.type,
                    title: message.title,
                    description: message.description,
                )
                // SwiftMessages creates a separate UIHostingController.
                .environmentObject(
                    theme,
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
