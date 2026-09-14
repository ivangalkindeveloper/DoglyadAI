import DoglyadUI
import SwiftUI

struct ScanTemplateCardView: DView {
    @EnvironmentObject var theme: DTheme

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

            ZStack(
                alignment: .topTrailing
            ) {
                DButtonCard(
                    backgroundColor: viewModel.isSelectedTemplateExaminationTypeMismatch
                        ? color.dangerBackground
                        : nil,
                    action: viewModel.onTapSelectedTemplate
                ) {
                    VStack(
                        alignment: .leading,
                        spacing: size.s4
                    ) {
                        if let template = ultrasoundViewModel.template {
                            DText(template.usExaminationType.getLocalizedTitle(for: Locale.current))
                                .dStyle(
                                    font: typography.linkSmall
                                )

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
                        } else {
                            DText(viewModel.usExaminationType.getLocalizedTitle(for: Locale.current))
                                .dStyle(
                                    font: typography.linkSmall
                                )

                            DText(.scanTemplateCardNoTemplateLabel)
                                .dStyle(
                                    font: typography.textXSmall,
                                    color: color.grayscalePlacehold
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(
                        .trailing,
                        ultrasoundViewModel.template == nil ? .zero : size.s32
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                }

                if ultrasoundViewModel.template != nil {
                    DCloseButton(
                        action: viewModel.onTapResetTemplate
                    )
                    .padding(size.s14)
                    .transition(.opacity)
                }
            }

            if viewModel.isSelectedTemplateExaminationTypeMismatch {
                Text(.scanTemplateCardExaminationTypeMismatchError)
                    .font(typography.textXSmall)
                    .foregroundStyle(color.dangerDefault)
                    .padding(.top, size.s4)
                    .padding(.horizontal, size.s8)
                    .transition(.opacity)
            }
        }
        .animation(
            theme.animation,
            value: viewModel.isSelectedTemplateExaminationTypeMismatch
        )
    }
}
