import DoglyadUI
import SwiftUI

struct NeuralModelReportCardView: DView {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject var theme: DTheme

    let report: USExaminationModelReport
    let onTapCopy: () -> Void

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: .zero
        ) {
            HStack(
                alignment: .top,
                spacing: .zero
            ) {
                VStack(
                    alignment: .leading,
                    spacing: .zero
                ) {
                    HStack(
                        alignment: .bottom,
                        spacing: .zero
                    ) {
                        DText(.reportResponseModelLabel)
                            .dStyle(
                                font: typography.textSmall
                            )
                            .padding(.trailing, size.s4)
                        if let modelTitle = container.getUSExaminationNeuralModelById(id: report.modelId)?.title {
                            DText(modelTitle)
                                .dStyle(
                                    font: typography.linkSmall
                                )
                        }
                    }

                    HStack(
                        alignment: .bottom,
                        spacing: .zero
                    ) {
                        DText(.reportResponseDateLabel)
                            .dStyle(
                                font: typography.textSmall
                            )
                            .padding(.trailing, size.s4)

                        DText(report.date.localized())
                            .dStyle(
                                font: typography.linkSmall
                            )
                    }
                }

                Spacer()

                Button(
                    action: onTapCopy
                ) {
                    DIcon(
                        .copy,
                        color: color.primaryDefault,
                        height: size.s20
                    )
                }
                .buttonStyle(.plain)
                .padding(.leading, size.s8)
            }
            .padding(.bottom, size.s16)

            reportSection(
                title: .reportDescriptionTitle,
                text: report.description,
                collapsedLineLimit: 12
            )

            reportSection(
                title: .reportConclusionTitle,
                text: report.conclusion,
                collapsedLineLimit: 8
            )
            .padding(.top, size.s16)

            if let recommendations = report.recommendations,
               !recommendations.isEmpty
            {
                reportSection(
                    title: .reportRecommendationsTitle,
                    text: recommendations,
                    collapsedLineLimit: 8
                )
                .padding(.top, size.s16)
            }
        }
        .padding(size.s16)
        .background(color.grayscaleBackground)
        .cornerRadius(size.s16)
    }

    private func reportSection(
        title: LocalizedStringResource,
        text: String,
        collapsedLineLimit: Int
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: size.s8
        ) {
            DText(title)
                .dStyle(
                    font: typography.linkSmall,
                    color: color.grayscalePlacehold
                )

            ExpandableMarkdownView(
                text: text,
                backgroundColor: color.grayscaleBackground,
                collapsedLineLimit: collapsedLineLimit
            )
        }
    }
}

#Preview {
    NeuralModelReportCardView(
        report: USExaminationModelReport(
            date: Date(),
            modelId: "google/medgemma-1.5-4b-it",
            description: "The thyroid is normally positioned with homogeneous parenchyma and smooth contours.",
            conclusion: "No sonographic evidence of focal thyroid lesions.",
            recommendations: "Routine follow-up when clinically indicated."
        ),
        onTapCopy: {}
    )
    .padding()
    .dThemeWrapper()
}
