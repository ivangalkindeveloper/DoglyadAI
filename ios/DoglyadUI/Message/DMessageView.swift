import SwiftUI
internal import SwiftMessages

struct DMessageModifier: ViewModifier {
    @EnvironmentObject private var theme: DTheme

    @StateObject var messager = DMessager()
    var isPersistent = false

    func body(
        content: Content,
    ) -> some View {
        var configuration = SwiftMessages.Config()
        if isPersistent {
            configuration.duration = .forever

            configuration.presentationContext = .window(
                windowLevel: .alert,
            )
        }

        return content
            .swiftMessage(
                message: $messager.message,
                config: configuration,
            ) { message in
                DMessageCard(
                    type: message.type,
                    title: message.title,
                    description: message.description,
                )
                .accessibilityIdentifier(
                    "message.\(message.type)",
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
