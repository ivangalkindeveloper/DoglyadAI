import DoglyadUI
import SwiftUI

struct ReadyMadeTemplateListItemCardView: DViewProtocol {
    @EnvironmentObject var theme: DTheme

    let template: USExaminationReadyMadeTemplate
    let examinationTypeTitle: LocalizedStringResource
    let action: () -> Void

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: size.s8,
        ) {
            DButtonCard(
                isPlain: true,
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
            .buttonStyle(
                .plain,
            )

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
            size.s16,
        )
    }
}
