import DoglyadUI
import SwiftUI

struct TemplateListItemCardView: DView {
    @EnvironmentObject var theme: DTheme

    let examinationTypeTitle: LocalizedStringResource
    let templateContent: String
    let action: () -> Void

    var body: some View {
        DButtonCard(
            action: action
        ) {
            VStack(
                alignment: .leading,
                spacing: size.s8
            ) {
                DText(examinationTypeTitle)
                    .dStyle(
                        font: typography.linkSmall,
                        color: color.grayscaleBackground
                    )
                    .multilineTextAlignment(.leading)
                    .padding(size.s10)
                    .background(
                        Capsule()
                            .fill(color.gradientPrimaryWeak)
                    )

                DText(templateContent)
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
        examinationTypeTitle: "Thyroid gland",
        templateContent: """
        An ultrasound examination was performed.
        The lobes are symmetrical.
        The parenchyma is homogeneous.
        No focal lesions were identified.
        An additional line demonstrates truncation.
        """,
        action: {}
    )
    .padding()
    .dThemeWrapper()
}
