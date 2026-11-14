import DoglyadUI
import SwiftUI

struct ScanTemplateCardView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: ScanViewModel
    var isDisabled: Bool = false

    init(
        isDisabled: Bool = false,
    ) {
        self.isDisabled = isDisabled
    }

    var body: some View {
        let trailingInset: CGFloat = viewModel.template == nil ? .zero : size.s32

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
                DCard(
                    action: viewModel.onTapSelectedTemplate,
                    content: {
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
                    },
                    isDisabled: isDisabled,
                    accessibilityIdentifier: "scan.template",
                )

                if viewModel.template != nil {
                    DCloseButton(
                        action: viewModel.onTapResetTemplate,
                        isDisabled: isDisabled,
                        accessibilityIdentifier: "scan.template.reset",
                    )

                    .padding(
                        size.s14,
                    )
                    .transition(
                        .opacity,
                    )
                }
            }

            if !viewModel.isTemplateCompatible {
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
            }
        }
    }
}
