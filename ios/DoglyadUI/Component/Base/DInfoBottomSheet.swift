import SwiftUI

public struct DInfoBottomSheet: DViewProtocol {
    @EnvironmentObject public var theme: DTheme

    private let fraction: Double
    private let title: LocalizedStringResource
    private let image: ImageResource
    private let description: LocalizedStringResource
    private let buttonTitle: LocalizedStringResource
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    private let action: () -> Void

    public init(
        fraction: Double = 0.3,
        title: LocalizedStringResource,
        image: ImageResource,
        description: LocalizedStringResource,
        buttonTitle: LocalizedStringResource,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void,
    ) {
        self.fraction = fraction
        self.title = title
        self.image = image
        self.description = description
        self.buttonTitle = buttonTitle
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier

        self.action = action
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
