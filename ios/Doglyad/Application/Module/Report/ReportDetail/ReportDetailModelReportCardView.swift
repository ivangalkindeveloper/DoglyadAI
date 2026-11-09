import DoglyadUI
import SwiftUI

struct ReportDetailModelReportCardView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject var theme: DTheme
    let report: USExaminationModelReport
    let onTapCopy: () -> Void
    var isDisabled: Bool = false

    private var generationFailureTitle: L10NKey? {
        switch report.generation.status {
        case .generating, .completed: nil
        case .interrupted: .reportGenerationInterruptedLabel
        case .failed, .cancelled: .reportGenerationIncompleteLabel
        }
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: .zero,
        ) {
            HStack(
                alignment: .top,
                spacing: .zero,
            ) {
                VStack(
                    alignment: .leading,
                    spacing: .zero,
                ) {
                    HStack(
                        alignment: .bottom,
                        spacing: .zero,
                    ) {
                        DText(
                            l10n[
                                .reportResponseModelLabel,
                            ],
                        )
                        .dStyle(
                            font: typography.textSmall,
                        )
                        .padding(
                            .trailing,
                            size.s4,
                        )
                        if let modelTitle = container.getUSExaminationNeuralModelById(
                            id: report.modelId,
                        )?.title {
                            DText(
                                modelTitle,
                            )
                            .dStyle(
                                font: typography.linkSmall,
                            )
                        }
                    }

                    HStack(
                        alignment: .bottom,
                        spacing: .zero,
                    ) {
                        DText(
                            l10n[
                                .reportResponseDateLabel,
                            ],
                        )
                        .dStyle(
                            font: typography.textSmall,
                        )
                        .padding(
                            .trailing,
                            size.s4,
                        )

                        DText(
                            report.date.localized(
                                locale: l10n.locale,
                            ),
                        )
                        .dStyle(
                            font: typography.linkSmall,
                        )
                    }
                }

                Spacer()

                if report.generation.status.isCompleted {
                    DTextButton(
                        action: onTapCopy,
                        content: {
                            DIcon(
                                .copy,
                                color: color.primaryDefault,
                                height: size.s20,
                            )
                        },
                        isDisabled: isDisabled,
                        accessibilityIdentifier: "reportDetail.copy.\(report.modelId)",
                    )
                    .buttonStyle(
                        .plain,
                    )

                    .padding(
                        .leading,
                        size.s8,
                    )
                }
            }
            .padding(
                .bottom,
                size.s16,
            )

            if let title = generationFailureTitle {
                DMessageCard(
                    type: .error,
                    title: l10n[
                        title,
                    ],
                    alignment: .center,
                )
                .padding(
                    .bottom,
                    size.s16,
                )
            }

            Group {
                ReportDetailModelReportSectionView(
                    title: l10n[
                        .reportDescriptionTitle,
                    ],
                    text: report.description,
                    collapsedLineLimit: 12,
                    isDisabled: isDisabled,
                )

                ReportDetailModelReportSectionView(
                    title: l10n[
                        .reportConclusionTitle,
                    ],
                    text: report.conclusion,
                    collapsedLineLimit: 8,
                    isDisabled: isDisabled,
                )
                .padding(
                    .top,
                    size.s16,
                )

                if let recommendations = report.recommendations {
                    ReportDetailModelReportSectionView(
                        title: l10n[
                            .reportRecommendationsTitle,
                        ],
                        text: recommendations,
                        collapsedLineLimit: 8,
                        isDisabled: isDisabled,
                    )
                    .padding(
                        .top,
                        size.s16,
                    )
                }
                if let descriptionRemarks = report.descriptionRemarks {
                    ReportDetailModelReportSectionView(
                        title: l10n[
                            .reportDescriptionRemarksTitle,
                        ],
                        text: descriptionRemarks,
                        collapsedLineLimit: 8,
                        isDisabled: isDisabled,
                    )
                    .padding(
                        .top,
                        size.s16,
                    )
                }
            }
            .dShimmer(
                isShimmering: report.generation.status == .generating,
                cornerRadius: 0,
                masksContent: true,
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
