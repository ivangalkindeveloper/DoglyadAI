import SwiftUI

public struct DIcon: DView {
    @EnvironmentObject public var theme: DTheme

    let resource: ImageResource
    let color: Color?
    let height: CGFloat?

    public init(
        _ resource: ImageResource,
        color: Color? = nil,
        height: CGFloat? = nil
    ) {
        self.resource = resource
        self.color = color
        self.height = height
    }

    public var body: some View {
        Image(resource)
            .resizable()
            .renderingMode(.template)
            .foregroundColor(color ?? theme.color.grayscaleHeader)
            .scaledToFit()
            .frame(width: height ?? size.s20, height: height ?? size.s20)
    }
}

#Preview {
    DIcon(
        .wifi,
        color: .red
    )
    .dThemeWrapper()
}
