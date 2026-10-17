import DoglyadUI
import SwiftUI

struct ScanTemplateCardView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @EnvironmentObject private var viewModel: ScanViewModel

    var body: some View {
        let backgroundColor: Color? = switch viewModel.isTemplateCompatible {
        case false: color.dangerBackground
        case true: nil
        }
        let trailingInset: CGFloat = switch viewModel.template {
        case .none: .zero
        case .some: size.s32
        }

        VStack(
            alignment: .leading,
            spacing: .zero,
        ) {
            DText(
                l10n[
                    .scanTemplateCardTitleLabel,
                ],
            )
            .dStyle(
                font: typography.textSmall,
                color: color.grayscalePlacehold,
            )
            .padding(
                .horizontal,
                size.s8,
            )
            .padding(
                .bottom,
                size.s8,
            )

            ZStack(
                alignment: .topTrailing,
            ) {
                DButtonCard(
                    backgroundColor: backgroundColor,
                    action: viewModel.onTapSelectedTemplate,
                ) {
                    VStack(
                        alignment: .leading,
                        spacing: size.s4,
                    ) {
                        switch viewModel.template {
                        case let .some(
                            template,
                        ):
                            DText(
                                template.usExaminationType.localizedTitle,
                            )
                            .dStyle(
                                font: typography.linkSmall,
                            )

                            DText(
                                template.name,
                            )
                            .dStyle(
                                font: typography.textSmall,
                                color: color.grayscalePlacehold,
                            )

                            DText(
                                template.content,
                            )
                            .dStyle(
                                font: typography.textXSmall,
                                color: color.grayscalePlacehold,
                            )
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading,
                            )
                            .lineLimit(
                                4,
                            )
                        case .none:
                            DText(
                                viewModel.usExaminationType.localizedTitle,
                            )
                            .dStyle(
                                font: typography.linkSmall,
                            )

                            DText(
                                l10n[
                                    .scanTemplateCardNoTemplateLabel,
                                ],
                            )
                            .dStyle(
                                font: typography.textXSmall,
                                color: color.grayscalePlacehold,
                            )
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading,
                            )
                        }
                    }
                    .padding(
                        .trailing,
                        trailingInset,
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading,
                    )
                }

                switch viewModel.template {
                case .some:
                    DCloseButton(
                        action: viewModel.onTapResetTemplate,
                    )
                    .padding(
                        size.s14,
                    )
                    .transition(
                        .opacity,
                    )
                case .none: EmptyView()
                }
            }

            switch viewModel.isTemplateCompatible {
            case false:
                DText(
                    l10n[
                        .scanTemplateCardExaminationTypeMismatchDescription,
                    ],
                )
                .dStyle(
                    font: typography.textXSmall,
                )
                .foregroundStyle(
                    color.dangerDefault,
                )
                .padding(
                    .top,
                    size.s4,
                )
                .padding(
                    .horizontal,
                    size.s8,
                )
                .transition(
                    .opacity,
                )
            case true: EmptyView()
            }
        }
    }
}
