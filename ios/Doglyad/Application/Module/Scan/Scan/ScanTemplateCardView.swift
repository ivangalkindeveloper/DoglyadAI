import DoglyadUI
import SwiftUI

struct ScanTemplateCardView: View {
    @EnvironmentObject private var theme: DTheme
    private var color: DColor { theme.color }
    private var size: DSize { theme.size }
    private var typography: DTypography { theme.typography }

    @EnvironmentObject private var viewModel: ScanViewModel
    @EnvironmentObject private var ultrasoundViewModel: UltrasoundViewModel

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: .zero
        ) {
            DText(.scanTemplateCardTitleLabel)
                .dStyle(
                    font: typography.textSmall,
                    color: color.grayscalePlacehold
                )
                .padding(.horizontal, size.s8)
                .padding(.bottom, size.s8)

            DButtonCard(
                action: viewModel.onTapSelectedTemplate
            ) {
                VStack(
                    alignment: .leading,
                    spacing: size.s8
                ) {
                    DText(
                        viewModel.usExaminationType.getLocalizedTitle(for: Locale.current)
                    )
                    .dStyle(
                        font: typography.linkSmall
                    )

                    if let template = ultrasoundViewModel.templateIdByUSExaminationTypeId[viewModel.usExaminationType.id] {
                        DText(template.content)
                            .dStyle(
                                font: typography.textXSmall,
                                color: color.grayscalePlacehold
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(4)
                    } else {
                        DText(.scanTemplateCardNoTemplateLabel)
                            .dStyle(
                                font: typography.textXSmall,
                                color: color.grayscalePlacehold
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
