import SwiftUI

public struct DFocusScrollView<Focus: Hashable, Content: View>: DView {
    @EnvironmentObject public var theme: DTheme

    @State private var keyboardHeight: CGFloat = .zero

    private let focus: Focus?
    private let axes: Axis.Set
    private let showsIndicators: Bool
    private let anchor: UnitPoint
    private let content: Content

    public init(
        focus: Focus?,
        axes: Axis.Set = .vertical,
        showsIndicators: Bool = false,
        anchor: UnitPoint = UnitPoint(x: 0.5, y: 0.35),
        @ViewBuilder content: () -> Content
    ) {
        self.focus = focus
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.anchor = anchor
        self.content = content()
    }

    public var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(
                    axes,
                    showsIndicators: showsIndicators
                ) {
                    content
                        .padding(.bottom, keyboardHeight)
                }
                .onChange(of: focus) { _, newValue in
                    guard let newValue else { return }
                    scroll(
                        to: newValue,
                        proxy: proxy
                    )
                }
                .onChange(of: keyboardHeight) { oldValue, newValue in
                    guard newValue > oldValue, let focus else { return }
                    scroll(
                        to: focus,
                        proxy: proxy
                    )
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: UIResponder.keyboardWillChangeFrameNotification
                    )
                ) { notification in
                    guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
                    else {
                        return
                    }

                    let scrollViewFrame = geometry.frame(in: .global)
                    let newKeyboardHeight = max(
                        .zero,
                        min(
                            scrollViewFrame.height,
                            scrollViewFrame.maxY - keyboardFrame.minY
                        )
                    )
                    guard keyboardHeight != newKeyboardHeight else { return }
                    withAnimation(theme.animation) {
                        keyboardHeight = newKeyboardHeight
                    }
                }
            }
        }
    }

    private func scroll(
        to focus: Focus,
        proxy: ScrollViewProxy
    ) {
        withAnimation(theme.animation) {
            proxy.scrollTo(
                focus,
                anchor: anchor
            )
        }
    }
}

#Preview {
    DFocusScrollView(
        focus: Optional(5)
    ) {
        VStack {
            ForEach(0 ..< 10) { index in
                DText("Item \(index)")
                    .dStyle()
                    .id(index)
            }
        }
    }
    .dThemeWrapper()
}
