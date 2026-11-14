import SwiftUI

public struct DInfoBottomSheet<Content: View>: DViewProtocol {
    @EnvironmentObject public var theme: DTheme
    private let fraction: Double
    private let title: LocalizedStringResource
    private let image: ImageResource
    private let description: LocalizedStringResource
    private let content: Content
    private let buttonTitle: LocalizedStringResource
    private let action: () -> Void
    private let isLoading: Bool
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    public init(
        fraction: Double = 0.3,
        title: LocalizedStringResource,
        image: ImageResource,
        description: LocalizedStringResource,
        @ViewBuilder content: () -> Content,
        buttonTitle: LocalizedStringResource,
        action: @escaping () -> Void,
        isLoading: Bool = false,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
    ) {
        self.fraction = fraction
        self.title = title
        self.image = image
        self.description = description
        self.content = content()
        self.buttonTitle = buttonTitle

        self.action = action
        self.isLoading = isLoading
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public init(
        fraction: Double = 0.3,
        title: LocalizedStringResource,
        image: ImageResource,
        description: LocalizedStringResource,
        buttonTitle: LocalizedStringResource,
        action: @escaping () -> Void,
        isLoading: Bool = false,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
    ) where Content == EmptyView {
        self.init(
            fraction: fraction,
            title: title,
            image: image,
            description: description,
            content: {
                EmptyView()
            },
            buttonTitle: buttonTitle,
            action: action,
            isLoading: isLoading,
            accessibilityElement: accessibilityElement,
            accessibilityIdentifier: accessibilityIdentifier,
        )
    }

    public var body: some View {
        Group {
            GeometryReader { proxy in
                DBottomSheet(
                    title: title,
                    fraction: fraction,
                ) { toolbarHeight, bottomHeight in
                    VStack(
                        spacing: size.s24,
                    ) {
                        DImage(
                            image,
                        )
                        .scaledToFit()
                        .frame(
                            width: proxy.size.width / 3,
                            height: proxy.size.width / 3,
                        )

                        DText(
                            description,
                        )
                        .dStyle(
                            font: typography.textSmall,
                            color: color.grayscalePlacehold,
                            alignment: .center,
                        )
                        .fixedSize(
                            horizontal: false,
                            vertical: true,
                        )

                        content
                    }
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                    )
                    .padding(
                        .top,
                        toolbarHeight + size.s24,
                    )
                    .padding(
                        .bottom,
                        bottomHeight + size.s24,
                    )
                    .padding(
                        .horizontal,
                        size.s16,
                    )
                } bottom: {
                    DButton(
                        title: buttonTitle,
                        action: action,
                        isLoading: isLoading,
                    )
                    .dStyle(
                        .primaryButton,
                    )
                    .padding(
                        .horizontal,
                        size.s16,
                    )
                }
            }
        }
        .modifier(
            DAccessibilityModifier(
                element: accessibilityElement,
                identifier: accessibilityIdentifier,
            ),
        )
    }
}
