import SwiftUI

public struct DIconBadge: DView {
    @EnvironmentObject public var theme: DTheme
    let resource: ImageResource
    let iconColor: Color
    let backgroundColor: Color

    public init(
        _ resource: ImageResource,
        iconColor: Color,
        backgroundColor: Color,
    ) {
        self.resource = resource
        self.iconColor = iconColor
        self.backgroundColor = backgroundColor
    }

    public var body: some View {
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
}
