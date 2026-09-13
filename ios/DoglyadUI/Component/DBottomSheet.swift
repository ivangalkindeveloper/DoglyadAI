import SwiftUI

public enum DBottomSheetType {
    case `default`
    case blur
}

public struct DBottomSheet<Content, Bottom>: DView where Content: View, Bottom: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject public var theme: DTheme

    @State private var toolbarHeight: CGFloat = 0
    @State private var bottomHeight: CGFloat = 0

    let type: DBottomSheetType
    let title: LocalizedStringResource
    let isCloseButtonVisible: Bool
    let fraction: Double
    let content: (CGFloat, CGFloat) -> Content
    let bottom: (() -> Bottom)?

    public init(
        type: DBottomSheetType = .default,
        title: LocalizedStringResource,
        isCloseButtonVisible: Bool = true,
        fraction: Double = 0.3,
        @ViewBuilder content: @escaping (CGFloat, CGFloat) -> Content,
        @ViewBuilder bottom: @escaping () -> Bottom
    ) {
        self.type = type
        self.title = title
        self.isCloseButtonVisible = isCloseButtonVisible
        self.fraction = fraction
        self.content = content
        self.bottom = bottom
    }

    public init(
        type: DBottomSheetType = .default,
        title: LocalizedStringResource,
        isCloseButtonVisible: Bool = true,
        fraction: Double = 0.3,
        @ViewBuilder content: @escaping (CGFloat, CGFloat) -> Content
    ) where Bottom == EmptyView {
        self.type = type
        self.title = title
        self.isCloseButtonVisible = isCloseButtonVisible
        self.fraction = fraction
        self.content = content
        bottom = nil
    }

    public var body: some View {
        GeometryReader { proxy in
            let safeAreaInsetBottom = proxy.safeAreaInsets.bottom

            ZStack(
                alignment: .top
            ) {
                ZStack {
                    content(toolbarHeight, bottomHeight - safeAreaInsetBottom)

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
                                                key: BottomSheetBottomHeightPreferenceKey.self,
                                                value: proxy.size.height
                                            )
                                    }
                                }
                                .onPreferenceChange(BottomSheetBottomHeightPreferenceKey.self) { value in
                                    guard bottomHeight != value else { return }
                                    bottomHeight = value
                                }
                                .transition(.move(edge: .bottom))
                        }
                    }
                    .edgesIgnoringSafeArea(.bottom)
                }

                toolbarView
                    .onPreferenceChange(BottomSheetToolbarHeightPreferenceKey.self) { value in
                        guard toolbarHeight != value else { return }
                        toolbarHeight = value
                    }
            }
            .presentationBackground { presentationBackgroundView }
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(size.adaptiveCornerRadius)
            .presentationDetents([.fraction(fraction)])
            .interactiveDismissDisabled(!isCloseButtonVisible)
            .if(type == .blur) {
                $0.preferredColorScheme(.dark)
            }
        }
    }

    private var toolbarSpacer: some View {
        Color.clear
            .frame(
                width: 22,
                height: .zero
            )
    }

    private var toolbarView: some View {
        VStack(
            spacing: .zero
        ) {
            HStack {
                toolbarSpacer
                Spacer()
                DText(title)
                    .dStyle(
                        font: typography.linkSmall,
                        color: type == .blur ? color.grayscaleBackgroundWeak : nil,
                        alignment: .center
                    )
                    .padding(size.s16)
                Spacer()
                if isCloseButtonVisible {
                    DCloseButton {
                        dismiss()
                    }
                } else {
                    toolbarSpacer
                }
            }
            .padding(.top, size.adaptiveCornerRadius / 4)
            .padding(.horizontal, size.adaptiveCornerRadius / 2)
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
                        key: BottomSheetToolbarHeightPreferenceKey.self,
                        value: proxy.size.height
                    )
            }
        }
    }

    @ViewBuilder
    private var presentationBackgroundView: some View {
        switch type {
        case .default:
            color.grayscaleBackgroundWeak
        case .blur:
            Rectangle().fill(.ultraThinMaterial)
        }
    }
}

private struct BottomSheetToolbarHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct BottomSheetBottomHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    @Previewable @State var isPresented = false

    Button("Show Sheet") {
        isPresented = true
    }
    .sheet(isPresented: $isPresented) {
        DBottomSheet(
            title: "Sheet Title",
            fraction: 0.4
        ) { toolbarHeight, _ in
            ScrollView {
                VStack(spacing: 12) {
                    DText("Bottom sheet content")
                        .dStyle()
                    DText("Some description text")
                        .dStyle()
                }
                .padding()
                .padding(.top, toolbarHeight)
            }
        } bottom: {
            DButton(
                title: "Confirm",
                action: { isPresented = false }
            )
            .dStyle(.primaryButton)
            .padding(.horizontal)
        }
        .dThemeWrapper()
    }
}
