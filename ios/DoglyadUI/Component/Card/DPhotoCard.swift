import SwiftUI

public struct DPhotoCard: DViewProtocol {
    @EnvironmentObject public var theme: DTheme
    private let image: UIImage
    private let configuration: DPhotoCardConfiguration
    private let onTap: (() -> Void)?
    private let isDisabled: Bool
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    public init(
        image: UIImage,
        configuration: DPhotoCardConfiguration = .init(),
        onTap: (() -> Void)? = nil,
        isDisabled: Bool = false,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = "photoCard.image",
    ) {
        self.image = image
        self.configuration = configuration
        self.onTap = onTap
        self.isDisabled = isDisabled
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
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
            guard !isDisabled else {
                return
            }
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
                            isDisabled: isDisabled,
                        )
                    }
                }
        }
        .disabled(
            isDisabled,
        )
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
