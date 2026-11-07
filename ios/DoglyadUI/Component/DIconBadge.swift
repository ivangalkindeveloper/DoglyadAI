import SwiftUI

public struct DIconBadge: DViewProtocol {
    @EnvironmentObject public var theme: DTheme
    let resource: ImageResource
    let iconColor: Color
    let backgroundColor: Color
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    public init(
        _ resource: ImageResource,
        iconColor: Color,
        backgroundColor: Color,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
    ) {
        self.resource = resource
        self.iconColor = iconColor
        self.backgroundColor = backgroundColor
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        Group {
            DIcon(
                resource,
                color: iconColor,
                height: size.s12,
            )
            .padding(
                size.s4,
            )
            .background(
                backgroundColor,
                in: Circle(),
            )
        }
        .modifier(
            DAccessibilityModifier(
                element: accessibilityElement,
                identifier: accessibilityIdentifier,
            ),
        )
    }
}
