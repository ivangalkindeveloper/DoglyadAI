import SwiftUI

public struct DFocusScrollView<Focus: Hashable, Content: View>: DView {
    @EnvironmentObject public var theme: DTheme

    private let focus: Focus?
    private let axes: Axis.Set
    private let showsIndicators: Bool
    private let anchor: UnitPoint
    private let content: Content

    public init(
        focus: Focus?,
        axes: Axis.Set = .vertical,
        showsIndicators: Bool = false,
        anchor: UnitPoint = .center,
        @ViewBuilder content: () -> Content
    ) {
        self.focus = focus
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.anchor = anchor
        self.content = content()
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView(
                axes,
                showsIndicators: showsIndicators
            ) {
                content
            }
            .onChange(of: focus) { _, newValue in
                guard let newValue else { return }
                withAnimation(theme.animation) {
                    proxy.scrollTo(newValue, anchor: anchor)
                }
            }
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
