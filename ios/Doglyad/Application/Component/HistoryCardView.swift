import DoglyadUI
import SwiftUI

struct HistoryCardView: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var theme: DTheme
    private var color: DColor { theme.color }
    private var size: DSize { theme.size }
    private var typography: DTypography { theme.typography }

    let report: USExaminationReport
    let onTap: () -> Void
    private var examinationData: USExaminationData {
        report.examinationData
    }

    var body: some View {
        DButtonCard(
            action: onTap
        ) {
            HStack(
                spacing: .zero
            ) {
                if !examinationData.photos.isEmpty {
                    ZStack {
                        ForEach(Array(examinationData.photos.enumerated()), id: \.element.id) { index, photo in
                            PhotoCardView(image: photo.thumbnail)
                                .offset(x: Double.random(in: -4 ... 4), y: Double.random(in: -4 ... 4))
                                .rotationEffect(.degrees(Double.random(in: -8 ... 8)))
                                .zIndex(Double(index))
                        }
                    }
                    .padding(.trailing, size.s20)
                }

                VStack(
                    alignment: .leading,
                    spacing: .zero
                ) {
                    HStack(
                        spacing: .zero
                    ) {
                        DText(examinationData.patientName)
                            .dStyle(
                                font: typography.linkSmall
                            )
                            .padding(.trailing, size.s8)

                        DText(report.date.localized())
                            .dStyle(
                                font: typography.textSmall,
                                color: color.grayscaleLabel
                            )
                    }

                    DText(
                        LocalizedStringResource.forExaminationTypeById(
                            types: container.usExaminationTypesById,
                            id: examinationData.usExaminationTypeId,
                            locale: Locale.current
                        )
                    )
                    .dStyle(
                        font: typography.linkSmall,
                        color: color.grayscalePlacehold
                    )

                    DText(examinationData.examinationDescription)
                        .dStyle(
                            font: typography.textSmall,
                            color: color.grayscaleLabel
                        )
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(color.grayscaleBackground)
        .cornerRadius(size.s16)
    }
}

#Preview {
    HistoryCardView(
        report: USExaminationReport(
            date: Date(),
            neuralModelSettings: NeuralModelSettings(
                selectedNeuralModelId: "google/medgemma-1.5-4b-it",
                isMarkdown: false,
                temperature: nil,
                maxTokens: nil
            ),
            examinationData: USExaminationData(
                usExaminationTypeId: "thyroidGland",
                photos: [
                    USExaminationScanPhoto(image: UIImage(resource: .alertInfo)),
                    USExaminationScanPhoto(image: UIImage(resource: .alertInfo)),
                    USExaminationScanPhoto(image: UIImage(resource: .alertInfo)),
                ],
                patientName: "Patient#0",
                patientGender: .male,
                patientDateOfBirth: Date(),
                patientHeight: 180.0,
                patientWeight: 80.0,
                patientComplaint: """
                The patient reports an intermittent feeling of pressure in the neck.
                They report mild discomfort while swallowing during the last two weeks.
                They also mention general weakness and increased fatigue.
                No similar symptoms were previously observed.
                The patient reports no pain.
                """,
                examinationDescription: """
                A thyroid ultrasound was performed in standard longitudinal and transverse planes.
                The lobes are symmetrical, with smooth and well-defined contours.
                The parenchyma is homogeneous with moderate echogenicity.
                No focal lesions were identified.
                The regional lymph nodes are unremarkable.
                """
            ),
            actualModelReport: USExaminationModelReport(
                date: Date(),
                modelId: "google/medgemma-1.5-4b-it",
                description: """
                No signs of thyroid nodules or cystic changes were identified.
                The organ dimensions are within the normal range for age.
                The parenchymal echotexture is preserved, with no pathological inclusions.
                No evidence of an inflammatory process was found.
                The ultrasound findings are within normal limits.
                """,
                conclusion: "The ultrasound findings are within normal limits.",
                recommendations: "Routine follow-up when clinically indicated."
            ),
            previousModelReports: [
                USExaminationModelReport(
                    date: Date(),
                    modelId: "google/medgemma-1.5-4b-it",
                    description: """
                    No signs of thyroid nodules or cystic changes were identified.
                    The organ dimensions are within the normal range for age.
                    The parenchymal echotexture is preserved, with no pathological inclusions.
                    No evidence of an inflammatory process was found.
                    The ultrasound findings are within normal limits.
                    """,
                    conclusion: "The ultrasound findings are within normal limits.",
                    recommendations: "Routine follow-up when clinically indicated."
                ),
                USExaminationModelReport(
                    date: Date(),
                    modelId: "google/medgemma-1.5-4b-it",
                    description: """
                    The thyroid is in its normal position and its structure is preserved.
                    Both lobes are within the normal size range for age, with no abnormalities.
                    Parenchymal echogenicity is uniform, without pathological decreases or increases.
                    No focal lesions, nodules, cysts, or calcifications were detected.
                    The gland contours are smooth and well defined; the capsule is not thickened.
                    Color Doppler shows no increased blood flow; values are physiological.
                    Regional lymph nodes show no enlargement or structural changes.
                    No signs of inflammation or autoimmune involvement were observed.
                    The findings correspond to a normal thyroid ultrasound appearance.
                    Routine follow-up ultrasound is recommended when clinically indicated.
                    """,
                    conclusion: "The findings correspond to a normal thyroid ultrasound appearance.",
                    recommendations: "Routine follow-up when clinically indicated."
                ),
            ]
        ),
        onTap: {}
    )
    .padding()
    .dThemeWrapper()
}
