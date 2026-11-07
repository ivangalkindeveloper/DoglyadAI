import SwiftUI

public struct DIcon: DViewProtocol {
    @EnvironmentObject public var theme: DTheme

    let resource: ImageResource
    let color: Color?
    let height: CGFloat?
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    public init(
        _ resource: ImageResource,
        color: Color? = nil,
        height: CGFloat? = nil,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
    ) {
        self.resource = resource
        self.color = color
        self.height = height
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        Group {
            Image(
                resource,
            )
            .resizable()
            .renderingMode(
                .template,
            )
            .foregroundColor(
                color ?? theme.color.grayscaleHeader,
            )
            .scaledToFit()
            .frame(
                width: height ?? size.s20,
                height: height ?? size.s20,
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

#Preview {
    DIcon(
        .wifi,
        color: .red,
    )
    .dThemeWrapper()
}
