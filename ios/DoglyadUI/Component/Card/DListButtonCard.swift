import SwiftUI

public struct DListButtonCard: DView {
    @EnvironmentObject public var theme: DTheme

    let image: ImageResource?
    let title: LocalizedStringResource
    let description: LocalizedStringResource?
    let action: () -> Void
    let isSelected: Bool

    public init(
        image: ImageResource? = nil,
        title: LocalizedStringResource,
        description: LocalizedStringResource? = nil,
        action: @escaping () -> Void,
        isSelected: Bool = false
    ) {
        self.image = image
        self.title = title
        self.description = description
        self.action = action
        self.isSelected = isSelected
    }

    public var body: some View {
        DButtonCard(
            action: action
        ) {
            HStack(
                alignment: .top,
                spacing: .zero
            ) {
                if let image = self.image {
                    Image(image)
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: size.s48,
                            height: size.s48
                        )
                        .padding(.trailing, size.s8)
                }

                VStack(
                    alignment: .leading,
                    spacing: .zero
                ) {
                    HStack(
                        alignment: .top,
                        spacing: .zero
                    ) {
                        DText(title)
                            .dStyle(
                                font: typography.linkSmall
                            )
                        Spacer()
                        if self.isSelected {
                            DIcon(
                                .check,
                                color: color.successDefault
                            )
                            .padding(.leading, size.s16)
                        }
                    }
                    if let description = self.description {
                        DText(description)
                            .dStyle(
                                font: typography.textXSmall,
                                color: color.grayscalePlacehold
                            )
                            .padding(.top, size.s4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }
}

#Preview {
    DListButtonCard(
        title: "Thyroid gland",
        action: {},
        isSelected: true
    )
    .padding()
    .dThemeWrapper()
}
