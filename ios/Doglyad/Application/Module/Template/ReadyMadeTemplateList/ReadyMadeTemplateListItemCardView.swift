import DoglyadUI
import SwiftUI

struct ReadyMadeTemplateListItemCardView: DView {
    @EnvironmentObject var theme: DTheme

    let template: USExaminationReadyMadeTemplate
    let examinationTypeTitle: LocalizedStringResource
    let action: () -> Void

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: size.s8
        ) {
            Button(
                action: action
            ) {
                VStack(
                    alignment: .leading,
                    spacing: size.s4
                ) {
                    DText(examinationTypeTitle)
                        .dStyle(
                            font: typography.linkSmall
                        )

                    DText(template.getLocalizedTitle(for: Locale.current))
                        .dStyle(
                            font: typography.linkSmall,
                            color: color.grayscalePlacehold
                        )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            ExpandableMarkdownView(
                text: template.getLocalizedContent(for: Locale.current),
                backgroundColor: color.grayscaleBackground,
                collapsedLineLimit: 4
            )
        }
        .padding(size.s16)
        .background(color.grayscaleBackground)
        .cornerRadius(size.s16)
    }
}

#Preview {
    ReadyMadeTemplateListItemCardView(
        template: USExaminationReadyMadeTemplate(
            id: "thyroidGlandStandard",
            examinationType: "thyroidGland",
            title: [
                "en": "Thyroid ultrasound",
                "ru": "УЗИ Щитовидной железы",
            ],
            content: [
                "en": "**Examination description:**\n\nThe thyroid gland is located in the typical position.",
                "ru": "**Описание исследования:**\n\nЩитовидная железа расположена в типичном месте.",
            ]
        ),
        examinationTypeTitle: "Thyroid gland",
        action: {}
    )
    .padding()
    .dThemeWrapper()
}
