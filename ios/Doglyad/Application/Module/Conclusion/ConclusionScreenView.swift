import DoglyadUI
import SwiftUI

struct ConclusionScreenView: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var theme: DTheme
    private var color: DColor { theme.color }
    private var size: DSize { theme.size }
    private var typography: DTypography { theme.typography }

    @StateObject var viewModel: ConclusionViewModel
    private var conclusion: USExaminationConclusion {
        viewModel.conclusion
    }

    private var examinationData: USExaminationData {
        viewModel.conclusion.examinationData
    }

    var body: some View {
        DScreen(
            title: .conclusionTitle,
            subTitle: "\(examinationData.patientName), \(conclusion.date.localized())",
            onTapBack: viewModel.onTapBack,
            trailing: {
                DButton(
                    image: .export,
                    action: viewModel.onTapShare
                )
                .dStyle(.circle)
            }
        ) { toolbarInset, _ in
            ScrollViewReader { proxy in
                ScrollView(
                    showsIndicators: false
                ) {
                    VStack(
                        alignment: .leading,
                        spacing: .zero
                    ) {
                        DText(
                            LocalizedStringResource.forExaminationTypeById(
                                types: container.usExaminationTypesById,
                                id: examinationData.usExaminationTypeId,
                                locale: Locale.current
                            )
                        )
                        .dStyle(
                            font: typography.linkLarge
                        )
                        .padding(.horizontal, size.s16)
                        .padding(.bottom, size.s16)

                        ConclusionPhotosView()

                        VStack(
                            alignment: .leading,
                            spacing: .zero
                        ) {
                            DText(.scanExaminationDateLabel)
                                .dStyle(
                                    font: typography.linkSmall,
                                    color: color.grayscalePlacehold
                                )

                            DText(conclusion.date.localized())
                                .dStyle(
                                    font: typography.textSmall
                                )
                                .padding(.bottom, size.s8)

                            DText(.scanPatientNameLabel)
                                .dStyle(
                                    font: typography.linkSmall,
                                    color: color.grayscalePlacehold
                                )

                            DText(examinationData.patientName)
                                .dStyle(
                                    font: typography.textSmall
                                )
                                .padding(.bottom, size.s8)

                            DText(.scanPatientGenderLabel)
                                .dStyle(
                                    font: typography.linkSmall,
                                    color: color.grayscalePlacehold
                                )

                            DText(.forGender(examinationData.patientGender))
                                .dStyle(
                                    font: typography.textSmall
                                )
                                .padding(.bottom, size.s8)

                            DText(.scanPatientDateOfBirthLabel)
                                .dStyle(
                                    font: typography.linkSmall,
                                    color: color.grayscalePlacehold
                                )

                            DText(examinationData.patientDateOfBirth.localized())
                                .dStyle(
                                    font: typography.textSmall
                                )
                                .padding(.bottom, size.s8)

                            DText(.scanExaminationDescriptionLabel)
                                .dStyle(
                                    font: typography.linkSmall,
                                    color: color.grayscalePlacehold
                                )

                            ExpandableText(
                                text: examinationData.examinationDescription,
                                backgroundColor: color.grayscaleBackgroundWeak
                            )
                            .padding(.bottom, size.s8)

                            DText(.scanPatientComplaintLabel)
                                .dStyle(
                                    font: typography.linkSmall,
                                    color: color.grayscalePlacehold
                                )

                            ExpandableText(
                                text: examinationData.patientComplaint,
                                backgroundColor: color.grayscaleBackgroundWeak
                            )
                            .padding(.bottom, size.s8)

                            DText(.conclusionActualModelResponseTitle)
                                .dStyle(
                                    font: typography.linkLarge
                                )
                                .padding(.top, size.s16)
                                .padding(.horizontal, size.s8)
                                .padding(.bottom, size.s16)

                            NeuralModelConclusionCard(
                                conclusion: conclusion.actualModelConclusion,
                                onTapCopy: { viewModel.onTapCopy(conclusion: conclusion.actualModelConclusion) }
                            )
                            .id(ConclusionViewModel.actualModelConclusionCardScrollId)
                            .padding(.bottom, size.s8)

                            NeuralModelCard(
                                onTap: viewModel.onTapNeuralModelSelection
                            )
                            .padding(.bottom, size.s16)

                            NeuralModelSettingsCard(
                                feature: .neuralModelSettings,
                                onTap: viewModel.onTapNeuralModelSettings
                            )

                            DButton(
                                image: .refresh,
                                title: .buttonRepeatScan,
                                action: {
                                    viewModel.onTapRepeatScan(
                                        proxy: proxy
                                    )
                                },
                                isLoading: viewModel.isLoading
                            )
                            .dStyle(.primaryButton)
                            .padding(.bottom, size.s16)

                            if !conclusion.previosModelConclusions.isEmpty {
                                DText(.conclusionPreviosModelResponsesTitle)
                                    .dStyle(
                                        font: typography.linkLarge
                                    )
                                    .padding(.top, size.s8)
                                    .padding(.horizontal, size.s8)
                                    .padding(.bottom, size.s16)

                                ForEach(conclusion.previosModelConclusions) { modelConclusion in
                                    NeuralModelConclusionCard(
                                        conclusion: modelConclusion,
                                        onTapCopy: { viewModel.onTapCopy(conclusion: modelConclusion) }
                                    )
                                    .padding(.bottom, size.s8)
                                }
                            }
                        }
                        .padding(.horizontal, size.s16)
                    }
                    .padding(.top, size.s16 + toolbarInset)
                    .padding(.bottom, size.s128)
                }
            }
        }
        .onAppear(perform: viewModel.onAppear)
        .environmentObject(viewModel)
    }
}
