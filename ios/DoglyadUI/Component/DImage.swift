import SwiftUI

public struct DImage: View {
    private enum Source {
        case resource(ImageResource)
        case photo(UIImage)
    }

    private let source: Source
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    public init(
        _ resource: ImageResource,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
    ) {
        source = .resource(
            resource,
        )
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public init(
        uiImage: UIImage,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
    ) {
        source = .photo(
            uiImage,
        )
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        Group {
            switch source {
            case let .resource(
                resource,
            ):
                Image(
                    resource,
                ).resizable()
            case let .photo(
                photo,
            ):
                Image(
                    uiImage: photo,
                ).resizable()
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
