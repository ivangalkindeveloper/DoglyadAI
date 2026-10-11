import SwiftUI

public struct DButtonCard<Content: View>: DView {
    @EnvironmentObject public var theme: DTheme

    let backgroundColor: Color?
    let isPlain: Bool
    let style: DButtonStyleType
    let action: () -> Void
    let content: () -> Content

    public init(
        backgroundColor: Color? = nil,
        isPlain: Bool = false,
        style: DButtonStyleType = .card,
        action: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content,
    ) {
        self.backgroundColor = backgroundColor
        self.isPlain = isPlain
        self.style = style
        self.content = content
        self.action = action
    }

    public var body: some View {
        Button(
            action: action,
        ) {
            content()
        }
        .if(
            isPlain,
        ) { view in
            view.buttonStyle(
                .plain,
            )
        }
        .if(
            !isPlain,
        ) { view in
            view.buttonStyle(
                DButtonStyle(
                    style,
                    backgroundColor: backgroundColor,
                ),
            )
        }
    }
}

#Preview {
    VStack(
        spacing: 16,
    ) {
        DButtonCard(
            action: { print(
                "Tap",
            ) },
        ) {
            HStack {
                DIcon(
                    .alertInfo,
                )
                DText(
                    "Button card",
                )
                .dStyle()
                Spacer()
            }
        }

        DButtonCard(
            action: { print(
                "Tap",
            ) },
        ) {
            DText(
                "Simple card",
            )
            .dStyle()
        }
    }
    .padding()
    .dThemeWrapper()
}
