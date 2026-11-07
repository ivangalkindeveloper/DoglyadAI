import SwiftUI

public enum DBottomSheetType {
    case `default`
    case blur
}

public struct DBottomSheet<Content, Bottom>: DViewProtocol where Content: View, Bottom: View {
    @Environment(
        \.dismiss,
    ) private var dismiss
    @EnvironmentObject public var theme: DTheme

    @State private var toolbarHeight: CGFloat = 0
    @State private var bottomHeight: CGFloat = 0

    let type: DBottomSheetType
    let title: LocalizedStringResource
    let isCloseButtonVisible: Bool
    let fraction: Double
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    let content: (CGFloat, CGFloat) -> Content
    let bottom: Bottom?

    public init(
        type: DBottomSheetType = .default,
        title: LocalizedStringResource,
        isCloseButtonVisible: Bool = true,
        fraction: Double = 0.3,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
        @ViewBuilder content: @escaping (CGFloat, CGFloat) -> Content,
        @ViewBuilder bottom: () -> Bottom?,
    ) {
        self.type = type
        self.title = title
        self.isCloseButtonVisible = isCloseButtonVisible
        self.fraction = fraction
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier

        self.content = content
        self.bottom = bottom()
    }

    public init(
        type: DBottomSheetType = .default,
        title: LocalizedStringResource,
        isCloseButtonVisible: Bool = true,
        fraction: Double = 0.3,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
        @ViewBuilder content: @escaping (CGFloat, CGFloat) -> Content,
    ) where Bottom == EmptyView {
        self.type = type
        self.title = title
        self.isCloseButtonVisible = isCloseButtonVisible
        self.fraction = fraction
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier

        self.content = content
        bottom = nil
    }

    public var body: some View {
        Group {
            GeometryReader { proxy in
                let safeAreaInsetBottom = proxy.safeAreaInsets.bottom

                ZStack(
                    alignment: .top,
                ) {
                    ZStack {
                        content(
                            toolbarHeight,
                            bottom == nil ? 0 : max(
                                0,
                                bottomHeight - safeAreaInsetBottom,
                            ),
                        )

                        VStack(
                            spacing: .zero,
                        ) {
                            Spacer()
                            if let bottom {
                                bottom
                                    .padding(
                                        .vertical,
                                        size.adaptiveCornerRadius / 6,
                                    )
                                    .frame(
                                        maxWidth: .infinity,
                                    )
                                    .safeAreaPadding(
                                        .bottom,
                                    )
                                    .background(
                                        Rectangle()
                                            .fill(
                                                .ultraThinMaterial,
                                            )
                                            .clipShape(
                                                DRoundedCorner(
                                                    radius: size.adaptiveCornerRadius,
                                                    corners: [.topLeft, .topRight],
                                                ),
                                            ),
                                    )
                                    .overlay {
                                        GeometryReader { proxy in
                                            Color.clear
                                                .preference(
                                                    key: BottomSheetBottomHeightPreferenceKey.self,
                                                    value: proxy.size.height,
                                                )
                                        }
                                    }
                                    .transition(
                                        .move(
                                            edge: .bottom,
                                        ),
                                    )
                            }
                        }
                        .edgesIgnoringSafeArea(
                            .bottom,
                        )
                        .onPreferenceChange(
                            BottomSheetBottomHeightPreferenceKey.self,
                        ) { value in
                            guard bottomHeight != value else {
                                return
                            }
                            bottomHeight = value
                        }
                    }

                    VStack(
                        spacing: .zero,
                    ) {
                        HStack {
                            Color.clear.frame(
                                width: 22,
                                height: .zero,
                            )

                            Spacer()

                            DText(
                                title,
                            )
                            .dStyle(
                                font: typography.linkSmall,
                                color: titleColor,
                                alignment: .center,
                            )
                            .padding(
                                size.s16,
                            )

                            Spacer()
                            if isCloseButtonVisible {
                                DCloseButton(
                                    accessibilityIdentifier: "bottomSheet.close",
                                ) {
                                    dismiss()
                                }

                            } else {
                                Color.clear.frame(
                                    width: 22,
                                    height: .zero,
                                )
                            }
                        }
                        .padding(
                            .top,
                            size.adaptiveCornerRadius / 4,
                        )
                        .padding(
                            .horizontal,
                            size.adaptiveCornerRadius / 2,
                        )
                    }
                    .frame(
                        maxWidth: .infinity,
                        alignment: .top,
                    )
                    .background {
                        Rectangle()
                            .fill(
                                .ultraThinMaterial,
                            )
                            .clipShape(
                                DRoundedCorner(
                                    radius: size.adaptiveCornerRadius,
                                    corners: [.bottomLeft, .bottomRight],
                                ),
                            )
                    }
                    .overlay {
                        GeometryReader { proxy in
                            Color.clear
                                .preference(
                                    key: BottomSheetToolbarHeightPreferenceKey.self,
                                    value: proxy.size.height,
                                )
                        }
                    }
                    .onPreferenceChange(
                        BottomSheetToolbarHeightPreferenceKey.self,
                    ) { value in
                        guard toolbarHeight != value else {
                            return
                        }
                        toolbarHeight = value
                    }
                }
                .presentationBackground {
                    switch type {
                    case .default:
                        color.grayscaleBackgroundWeak
                    case .blur:
                        Rectangle().fill(
                            .ultraThinMaterial,
                        )
                    }
                }
                .presentationDragIndicator(
                    .hidden,
                )
                .presentationCornerRadius(
                    size.adaptiveCornerRadius,
                )
                .presentationDetents(
                    [.fraction(
                        fraction,
                    )],
                )
                .interactiveDismissDisabled(
                    !isCloseButtonVisible,
                )
                .preferredColorScheme(
                    preferredColorScheme,
                )
            }
        }
        .modifier(
            DAccessibilityModifier(
                element: accessibilityElement,
                identifier: accessibilityIdentifier,
            ),
        )
    }

    private var preferredColorScheme: ColorScheme? {
        switch type {
        case .default: nil
        case .blur: .dark
        }
    }

    private var titleColor: Color? {
        switch type {
        case .default: nil
        case .blur: color.grayscaleBackgroundWeak
        }
    }
}

private struct BottomSheetToolbarHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(
        value: inout CGFloat,
        nextValue: () -> CGFloat,
    ) {
        value = nextValue()
    }
}

private struct BottomSheetBottomHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(
        value: inout CGFloat,
        nextValue: () -> CGFloat,
    ) {
        value = nextValue()
    }
}

#Preview {
    @Previewable @State var isPresented = false

    Button(
        "Show Sheet",
    ) {
        isPresented = true
    }
    .sheet(
        isPresented: $isPresented,
    ) {
        DBottomSheet(
            title: "Sheet Title",
            fraction: 0.4,
        ) { toolbarHeight, _ in
            ScrollView {
                VStack(
                    spacing: 12,
                ) {
                    DText(
                        "Bottom sheet content",
                    )
                    .dStyle()

                    DText(
                        "Some description text",
                    )
                    .dStyle()
                }
                .padding()
                .padding(
                    .top,
                    toolbarHeight,
                )
            }
        } bottom: {
            DButton(
                title: "Confirm",
                action: {
                    isPresented = false
                },
            )
            .dStyle(
                .primaryButton,
            )
            .padding(
                .horizontal,
            )
        }
        .dThemeWrapper()
    }
}
