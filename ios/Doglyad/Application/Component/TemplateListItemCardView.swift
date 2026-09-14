import DoglyadUI
import SwiftUI

struct TemplateListItemCardView: DView {
    @EnvironmentObject var theme: DTheme

    let template: USExaminationTemplate
    let action: () -> Void
    let isSelected: Bool

    init(
        template: USExaminationTemplate,
        action: @escaping () -> Void,
        isSelected: Bool = false
    ) {
        self.template = template
        self.action = action
        self.isSelected = isSelected
    }

    var body: some View {
        DButtonCard(
            action: action
        ) {
            VStack(
                alignment: .leading,
                spacing: size.s4
            ) {
                HStack(
                    alignment: .top,
                    spacing: .zero
                ) {
                    DText(template.usExaminationType.getLocalizedTitle(for: Locale.current))
                        .dStyle(
                            font: typography.linkSmall
                        )

                    Spacer()

                    if isSelected {
                        DIcon(
                            .check,
                            color: color.successDefault
                        )
                        .padding(.leading, size.s16)
                    }
                }

                DText(template.name)
                    .dStyle(
                        font: typography.textSmall,
                        color: color.grayscalePlacehold
                    )

                DText(template.content)
                    .dStyle(
                        font: typography.textXSmall,
                        color: color.grayscalePlacehold
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    TemplateListItemCardView(
        template: USExaminationTemplate(
            usExaminationType: USExaminationType(
                id: "thyroid",
                title: [
                    "en": "Thyroid gland",
                    "ru": "Щитовидная железа",
                ]
            ),
            name: "Standard examination",
            content: """
            An ultrasound examination was performed.
            The lobes are symmetrical.
            The parenchyma is homogeneous.
            No focal lesions were identified.
            An additional line demonstrates truncation.
            """
        ),
        action: {},
        isSelected: true
    )
    .padding()
    .dThemeWrapper()
}
