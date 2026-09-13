import DoglyadUI
import SwiftUI

struct ScanMediaButtonView: DView {
    @EnvironmentObject var theme: DTheme

    let image: ImageResource
    let title: LocalizedStringResource
    let action: () -> Void

    var body: some View {
        DButtonCard(
            action: action
        ) {
            VStack(
                spacing: size.s4
            ) {
                DIcon(
                    image,
                    color: color.primaryDefault,
                    height: size.s24
                )

                DText(title)
                    .dStyle(
                        font: typography.linkXSmall,
                        color: color.primaryDefault,
                        alignment: .center
                    )
            }
            .frame(
                maxWidth: .infinity,
                minHeight: size.s36
            )
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: size.adaptiveCardCornerRadius
            )
            .stroke(
                color.primaryDefault,
                style: StrokeStyle(
                    lineWidth: 1,
                    lineCap: .round,
                    dash: [size.s8, size.s4]
                )
            )
        }
    }
}

#Preview {
    HStack {
        ScanMediaButtonView(
            image: .camera,
            title: "Camera",
            action: {}
        )
        ScanMediaButtonView(
            image: .image,
            title: "Gallery",
            action: {}
        )
    }
    .padding()
    .dThemeWrapper()
}
