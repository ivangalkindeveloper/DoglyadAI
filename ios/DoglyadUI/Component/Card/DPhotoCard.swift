import SwiftUI

public struct DPhotoCard: DViewProtocol {
    @EnvironmentObject public var theme: DTheme

    private let image: UIImage
    private let configuration: DPhotoCardConfiguration
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?
    private let onTap: (() -> Void)?

    public init(
        image: UIImage,
        configuration: DPhotoCardConfiguration = .init(),
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = "photoCard.image",
        onTap: (() -> Void)? = nil,
    ) {
        self.image = image
        self.configuration = configuration
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
        self.onTap = onTap
    }

    public var body: some View {
        DImage(
            uiImage: image,
            accessibilityElement: accessibilityElement,
            accessibilityIdentifier: accessibilityIdentifier,
        )
        .aspectRatio(
            contentMode: .fill,
        )
        .frame(
            width: size.s64,
            height: size.s64,
        )
        .clipped()
        .cornerRadius(
            size.adaptiveCornerRadius / 4,
        )
        .onTapGesture {
            onTap?()
        }

        .if(
            configuration.isBadgeVisible,
        ) { view in
            view
                .padding(
                    .top,
                    size.s8,
                )
                .padding(
                    .trailing,
                    size.s8,
                )
                .overlay(
                    alignment: .topTrailing,
                ) {
                    if let badge = configuration.badge {
                        DPhotoCardBadgeView(
                            badge: badge,
                        )
                    }
                }
        }
    }
}

#Preview {
    DPhotoCard(
        image: .alertInfo,
        configuration: DPhotoCardConfiguration(
            badge: .delete(
                action: {},
            ),
        ),
    )
    .padding()
    .dThemeWrapper()
}
