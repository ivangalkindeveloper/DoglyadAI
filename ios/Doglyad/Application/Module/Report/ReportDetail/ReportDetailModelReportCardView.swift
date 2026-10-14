import DoglyadUI
import SwiftUI

struct ReportDetailModelReportCardView: DView {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject var theme: DTheme

    let report: USExaminationModelReport
    let onTapCopy: () -> Void

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

                DButtonCard(
                    isPlain: true,
                    action: onTapCopy,
                ) {
                    DIcon(
                        .copy,
                        color: color.primaryDefault,
                        height: size.s20,
                    )
                }
                .buttonStyle(
                    .plain,
                )
                .padding(
                    .leading,
                    size.s8,
                )
            }
            .padding(
                .bottom,
                size.s16,
            )

            ReportDetailModelReportSectionView(
                title: l10n[
                    .reportDescriptionTitle,
                ],
                text: report.description,
                collapsedLineLimit: 12,
            )

            ReportDetailModelReportSectionView(
                title: l10n[
                    .reportConclusionTitle,
                ],
                text: report.conclusion,
                collapsedLineLimit: 8,
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
                )
                .padding(
                    .top,
                    size.s16,
                )
            }
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

#Preview {
    ReportDetailModelReportCardView(
        report: USExaminationModelReport(
            date: Date(),
            modelId: "google/medgemma-1.5-4b-it",
            description: "The thyroid is normally positioned with homogeneous parenchyma and smooth contours.",
            conclusion: "No sonographic evidence of focal thyroid lesions.",
            recommendations: "Routine follow-up when clinically indicated.",
        ),
        onTapCopy: {},
    )
    .padding()
    .dThemeWrapper()
    .localization(
        DependencyContainer.previewable.l10n,
    )
}
