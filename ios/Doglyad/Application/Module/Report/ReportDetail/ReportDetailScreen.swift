import DoglyadUI
import Router
import SwiftUI

struct ReportDetailScreen: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var messager: DMessager
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var ultrasoundViewModel: UltrasoundViewModel
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel
    let arguments: ReportDetailScreenArguments

    var body: some View {
        ReportDetailScreenView(
            viewModel: ReportDetailViewModel(
                container: container,
                messager: messager,
                router: router,
                initialReport: arguments.report,
                subscription: subscriptionViewModel,
                getSelectedTemplate: { [ultrasoundViewModel] in
                    ultrasoundViewModel.template
                },
                getNeuralModel: { [ultrasoundViewModel] in
                    ultrasoundViewModel.neuralModel
                },
                onNeuralModelSelected: { [ultrasoundViewModel] model in
                    ultrasoundViewModel.saveNeuralModel(model)
                }
            )
        )
    }
}

#Preview {
    ReportDetailScreen(
        arguments: ReportDetailScreenArguments(
            report: USExaminationReport(
                date: Date(),
                neuralModelSettings: NeuralModelSettings(
                    selectedNeuralModelId: "google/medgemma-1.5-4b-it",
                    isMarkdown: false,
                    temperature: nil,
                    maxTokens: nil
                ),
                examinationData: USExaminationData(
                    usExaminationTypeId: "abdominalCavity",
                    photos: [
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
            )
        )
    )
    .previewable()
}
