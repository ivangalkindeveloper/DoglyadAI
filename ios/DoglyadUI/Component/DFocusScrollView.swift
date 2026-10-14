import SwiftUI

public struct DFocusScrollView<Focus: Hashable, Content: View>: DView {
    @EnvironmentObject public var theme: DTheme

    @State private var keyboardHeight: CGFloat = .zero

    private let focus: Focus?
    private let axes: Axis.Set
    private let isIndicatorsVisible: Bool
    private let anchor: UnitPoint
    private let content: Content

    public init(
        focus: Focus?,
        axes: Axis.Set = .vertical,
        isIndicatorsVisible: Bool = false,
        anchor: UnitPoint = UnitPoint(
            x: 0.5,
            y: 0.35,
        ),
        @ViewBuilder content: () -> Content,
    ) {
        self.focus = focus
        self.axes = axes
        self.isIndicatorsVisible = isIndicatorsVisible
        self.anchor = anchor
        self.content = content()
    }

    public var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(
                    axes,
                    showsIndicators: isIndicatorsVisible,
                ) {
                    content
                        .padding(
                            .bottom,
                            keyboardHeight,
                        )
                }
                .onChange(
                    of: focus,
                ) { _, newValue in
                    guard let newValue else { return }
                    DFocusScrollController.scroll(
                        to: newValue,
                        proxy: proxy,
                        anchor: anchor,
                        animation: theme.animation,
                    )
                }
                .onChange(
                    of: keyboardHeight,
                ) { oldValue, newValue in
                    guard newValue > oldValue, let focus else { return }
                    DFocusScrollController.scroll(
                        to: focus,
                        proxy: proxy,
                        anchor: anchor,
                        animation: theme.animation,
                    )
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: UIResponder.keyboardWillChangeFrameNotification,
                    ),
                ) { notification in
                    guard let keyboardFrame = notification.userInfo?[
                        UIResponder.keyboardFrameEndUserInfoKey,
                    ] as? CGRect
                    else {
                        return
                    }

                    let scrollViewFrame = geometry.frame(
                        in: .global,
                    )
                    let newKeyboardHeight = max(
                        .zero,
                        min(
                            scrollViewFrame.height,
                            scrollViewFrame.maxY - keyboardFrame.minY,
                        ),
                    )
                    guard keyboardHeight != newKeyboardHeight else { return }
                    withAnimation(
                        theme.animation,
                    ) {
                        keyboardHeight = newKeyboardHeight
                    }
                }
            }
        }
    }
}

#Preview {
    DFocusScrollView(
        focus: Optional(
            5,
        ),
    ) {
        VStack {
            ForEach(
                0 ..< 10,
            ) { index in
                DText(
                    "Item \(index)",
                )
                .dStyle()
                .id(
                    index,
                )
            }
        }
    }
    .dThemeWrapper()
}
