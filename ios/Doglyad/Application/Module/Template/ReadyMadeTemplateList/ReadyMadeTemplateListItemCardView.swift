import DoglyadUI
import SwiftUI

struct ReadyMadeTemplateListItemCardView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    let template: USExaminationReadyMadeTemplate
    let examinationTypeTitle: LocalizedStringResource
    let action: () -> Void

    init(
        template: USExaminationReadyMadeTemplate,
        examinationTypeTitle: LocalizedStringResource,
        action: @escaping () -> Void,
    ) {
        self.template = template
        self.examinationTypeTitle = examinationTypeTitle
        self.action = action
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: size.s8,
        ) {
            DTextButton(
                action: action,
            ) {
                VStack(
                    alignment: .leading,
                    spacing: size.s4,
                ) {
                    DText(
                        examinationTypeTitle,
                    )
                    .dStyle(
                        font: typography.linkSmall,
                    )

                    DText(
                        template.localizedTitle,
                    )
                    .dStyle(
                        font: typography.linkSmall,
                        color: color.grayscalePlacehold,
                    )
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading,
                )
                .contentShape(
                    Rectangle(),
                )
            }

            ReadyMadeTemplateListExpandableTextView(
                text: template.content,
                backgroundColor: color.grayscaleBackground,
                collapsedLineLimit: 8,
                onTapContent: action,
            )
        }
        .padding(
            size.s16,
        )
        .background(
            color.grayscaleBackground,
        )
        .cornerRadius(
            size.cardCornerRadius,
        )
    }
}
