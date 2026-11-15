import SwiftUI

public struct DAssetScaleImage: DViewProtocol {
    @EnvironmentObject public var theme: DTheme
    private let resource: ImageResource
    private let widthScale: DAssetImageWidthScale
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    public init(
        _ resource: ImageResource,
        widthScale: DAssetImageWidthScale,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
    ) {
        self.resource = resource
        self.widthScale = widthScale
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        Image(
            resource,
        )
        .resizable()
        .scaledToFit()
        .frame(
            width: size.screenWidth * widthScale.rawValue,
        )
        .modifier(
            DAccessibilityModifier(
                element: accessibilityElement,
                identifier: accessibilityIdentifier,
            ),
        )
    }
}
