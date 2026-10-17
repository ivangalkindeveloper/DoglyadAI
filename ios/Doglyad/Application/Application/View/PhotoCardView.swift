import DoglyadUI
import SwiftUI

struct PhotoCardView: DViewProtocol {
    @EnvironmentObject var theme: DTheme

    let image: UIImage
    let configuration: PhotoCardConfiguration
    let onTap: (() -> Void)?

    init(
        image: UIImage,
        configuration: PhotoCardConfiguration = .init(),
        onTap: (() -> Void)? = nil,
    ) {
        self.image = image
        self.configuration = configuration
        self.onTap = onTap
    }

    var body: some View {
        DImage(
            uiImage: image,
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
        .onTapGesture { onTap?() }
        .accessibilityAddTraits(
            onTap == nil ? [] : .isButton,
        )
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
                    badgeView
                }
        }
    }

    @ViewBuilder
    private var badgeView: some View {
        if let badge = configuration.badge {
            switch badge {
            case let .delete(
                action,
            ):
                DCloseButton(
                    style: .destructive,
                    action: action,
                )
            case let .warning(
                accessibilityLabel,
            ):
                DIconBadge(
                    .alert,
                    iconColor: color.warningDefaultStrong,
                    backgroundColor: color.warningDefault,
                )
                .accessibilityLabel(
                    Text(
                        accessibilityLabel,
                    ),
                )
                .allowsHitTesting(
                    false,
                )
            }
        }
    }
}

#Preview {
    PhotoCardView(
        image: .alertInfo,
        configuration: PhotoCardConfiguration(
            badge: .delete(
                action: {},
            ),
        ),
    )
    .padding()
    .dThemeWrapper()
}
