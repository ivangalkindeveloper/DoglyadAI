import DoglyadUI
import Router
import SwiftUI

struct ShareBottomSheet: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var messager: DMessager
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var ultrasoundViewModel: UltrasoundViewModel
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel
    let arguments: ShareArguments

    var body: some View {
        ShareBottomSheetView(
            viewModel: ShareViewModel(
                container: container,
                messager: messager,
                router: router,
                arguments: arguments,
                subscription: subscriptionViewModel,
                userEmail: ultrasoundViewModel.userEmail
            )
        )
    }
}

#Preview {
    ShareBottomSheet(
        arguments: ShareArguments(
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
                    photos: [],
                    examinationNumber: "Examination#0",
                    patientName: "Patient#0",
                    patientGender: .male,
                    patientDateOfBirth: Date(),
                    patientHeight: 180.0,
                    patientWeight: 80.0,
                    patientComplaints: "Patient complaints",
                    examinationDescription: "Examination description"
                ),
                actualModelReport: USExaminationModelReport(
                    date: Date(),
                    modelId: "google/medgemma-1.5-4b-it",
                    description: "The thyroid has homogeneous echogenicity and smooth contours.",
                    conclusion: "The ultrasound findings are within normal limits.",
                    recommendations: "Routine follow-up when clinically indicated."
                ),
                previousModelReports: []
            )
        )
    )
    .previewable()
}
