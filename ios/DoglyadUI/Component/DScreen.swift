import SwiftUI

public enum DScreenToolbarType {
    case solid, blur
}

public struct DScreen<Leading: View, Title: View, Trailing: View, Content: View, Bottom: View>: View {
    @EnvironmentObject private var theme: DTheme
    private var color: DColor { theme.color }
    private var size: DSize { theme.size }
    private var typography: DTypography { theme.typography }

    @State private var toolbarHeight: CGFloat = 0
    @State private var bottomHeight: CGFloat = 0

    let toolbarType: DScreenToolbarType
    let title: LocalizedStringResource?
    let subTitle: String?
    let backgroundColor: Color?
    let onTapBack: (() -> Void)?
    let leading: Leading
    let titleContent: Title
    let trailing: Trailing
    let onTapBody: (() -> Void)?
    let content: (CGFloat, CGFloat) -> Content
    let bottom: (() -> Bottom)?

    public init(
        toolbarType: DScreenToolbarType = .solid,
        title: LocalizedStringResource? = nil,
        subTitle: String? = nil,
        backgroundColor: Color? = nil,
        onTapBack: (() -> Void)? = nil,
        @ViewBuilder leading: @escaping (() -> Leading) = { EmptyView() },
        @ViewBuilder titleContent: @escaping (() -> Title) = { EmptyView() },
        @ViewBuilder trailing: @escaping (() -> Trailing) = { EmptyView() },
        onTapBody: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (CGFloat, CGFloat) -> Content
    ) where Bottom == EmptyView {
        self.toolbarType = toolbarType
        self.title = title
        self.subTitle = subTitle
        self.backgroundColor = backgroundColor
        self.onTapBack = onTapBack
        self.leading = leading()
        self.titleContent = titleContent()
        self.trailing = trailing()
        self.onTapBody = onTapBody
        self.content = content
        bottom = nil
    }

    public init(
        toolbarType: DScreenToolbarType = .solid,
        title: LocalizedStringResource? = nil,
        subTitle: String? = nil,
        backgroundColor: Color? = nil,
        onTapBack: (() -> Void)? = nil,
        @ViewBuilder leading: @escaping (() -> Leading) = { EmptyView() },
        @ViewBuilder titleContent: @escaping (() -> Title) = { EmptyView() },
        @ViewBuilder trailing: @escaping (() -> Trailing) = { EmptyView() },
        onTapBody: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (CGFloat, CGFloat) -> Content,
        @ViewBuilder bottom: @escaping () -> Bottom
    ) {
        self.toolbarType = toolbarType
        self.title = title
        self.subTitle = subTitle
        self.backgroundColor = backgroundColor
        self.onTapBack = onTapBack
        self.leading = leading()
        self.titleContent = titleContent()
        self.trailing = trailing()
        self.onTapBody = onTapBody
        self.content = content
        self.bottom = bottom
    }

    public var body: some View {
        GeometryReader { proxy in
            let safeAreaInsetTop = proxy.safeAreaInsets.top
            let safeAreaInsetBottom = proxy.safeAreaInsets.bottom

            ZStack(
                alignment: .top
            ) {
                bodyView(toolbarHeight - safeAreaInsetTop, bottomHeight - safeAreaInsetBottom)

                VStack(
                    spacing: .zero
                ) {
                    Spacer()
                    if let bottom = self.bottom?() {
                        bottom
                            .padding(.vertical, size.adaptiveCornerRadius / 6)
                            .frame(maxWidth: .infinity)
                            .safeAreaPadding(.bottom)
                            .background(
                                Rectangle()
                                    .fill(.ultraThinMaterial)
                                    .clipShape(
                                        DRoundedCorner(
                                            radius: size.adaptiveCornerRadius,
                                            corners: [.topLeft, .topRight]
                                        )
                                    )
                            )
                            .overlay {
                                GeometryReader { proxy in
                                    Color.clear
                                        .preference(
                                            key: BottomHeightPreferenceKey.self,
                                            value: proxy.size.height
                                        )
                                }
                            }
                            .onPreferenceChange(BottomHeightPreferenceKey.self) { value in
                                guard bottomHeight != value else { return }
                                bottomHeight = value
                            }
                            .transition(.move(edge: .bottom))
                    }
                }
                .edgesIgnoringSafeArea(.bottom)

                if isShowsToolbar {
                    toolbarView(safeAreaInsetTop)
                        .onPreferenceChange(ToolbarHeightPreferenceKey.self) { value in
                            guard toolbarHeight != value else { return }
                            toolbarHeight = value
                        }
                        .onChange(of: isShowsToolbar) { _, value in
                            if !value {
                                toolbarHeight = 0
                            }
                        }
                        .ignoresSafeArea(.container, edges: [.top])
                }
            }
            .background(backgroundColor ?? color.grayscaleBackgroundWeak)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DInteractivePopGestureView())
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private var isShowsToolbar: Bool {
        title != nil
            || subTitle != nil
            || onTapBack != nil
            || !(leading is EmptyView)
            || !(titleContent is EmptyView)
            || !(trailing is EmptyView)
    }

    private func bodyView(
        _ toolbarHeight: CGFloat,
        _ bottomHeight: CGFloat
    ) -> some View {
        content(toolbarHeight, bottomHeight)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onTapGesture { onTapBody?() }
    }

    private func toolbarView(
        _ safeAreaInsetTop: CGFloat
    ) -> some View {
        VStack(
            spacing: .zero
        ) {
            HStack(
                spacing: size.s8
            ) {
                leadingView
                Spacer()
                titleView
                Spacer()
                trailingView
            }
            .padding(.top, size.s2 + safeAreaInsetTop)
            .padding(.horizontal, size.adaptiveCornerRadius / 4)
            .padding(.bottom, size.adaptiveCornerRadius / 4)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .clipShape(DRoundedCorner(
                    radius: size.adaptiveCornerRadius,
                    corners: [.bottomLeft, .bottomRight]
                ))
        }
        .overlay {
            GeometryReader { proxy in
                Color.clear
                    .preference(
                        key: ToolbarHeightPreferenceKey.self,
                        value: proxy.size.height
                    )
            }
        }
    }

    private var leadingView: some View {
        HStack(
            spacing: size.s8
        ) {
            if let onTapBack = onTapBack {
                DButton(
                    image: .back,
                    action: onTapBack
                )
                .dStyle(.circle)
            }
            if !(leading is EmptyView) {
                leading
            }
        }
        .frame(width: size.s56, height: size.s56)
    }

    private var titleView: some View {
        VStack(
            spacing: .zero
        ) {
            if !(titleContent is EmptyView) {
                titleContent
            }
            if let title = title {
                DText(title)
                    .dStyle(
                        font: typography.linkSmall,
                        alignment: .center
                    )
            }
            if let subTitle = subTitle {
                DText(subTitle)
                    .dStyle(
                        font: typography.textXSmall,
                        color: color.grayscaleLabel,
                        alignment: .center
                    )
            }
        }
    }

    private var trailingView: some View {
        HStack(
            spacing: size.s8
        ) {
            if !(trailing is EmptyView) {
                trailing
            }
        }
        .frame(width: size.s56, height: size.s56)
    }
}

private struct ToolbarHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct BottomHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview("With toolbar") {
    DScreen(
        title: "Screen Title",
        subTitle: "Subtitle",
        onTapBack: { print("Back") },
        trailing: {
            DButton(
                image: .alertInfo,
                action: { print("Info") }
            )
            .dStyle(.circle)
        }
    ) { toolbarHeight, _ in
        ScrollView {
            VStack(spacing: 16) {
                ForEach(0 ..< 10, id: \.self) { index in
                    DText("Item \(index)")
                        .dStyle()
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .padding(.top, toolbarHeight)
        }
    }
    .dThemeWrapper()
}

#Preview("Without toolbar") {
    DScreen { _, _ in
        VStack {
            DText("Content without toolbar")
                .dStyle()
        }
    }
    .dThemeWrapper()
}
