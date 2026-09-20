import DoglyadUI
import SwiftUI

struct ReportDetailScreenView: DView {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: ReportDetailViewModel
    private var report: USExaminationReport {
        viewModel.report
    }

    private var examinationData: USExaminationData {
        viewModel.report.examinationData
    }

    var body: some View {
        DScreen(
            title: .reportTitle,
            subTitle: viewModel.subTitle,
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

                        ReportDetailPhotosView()

                        VStack(
                            alignment: .leading,
                            spacing: .zero
                        ) {
                            DText(.scanExaminationDateLabel)
                                .dStyle(
                                    font: typography.linkSmall,
                                    color: color.grayscalePlacehold
                                )

                            DText(report.date.localized())
                                .dStyle(
                                    font: typography.textSmall
                                )
                                .padding(.bottom, size.s8)

                            DText(.scanExaminationNumberLabel)
                                .dStyle(
                                    font: typography.linkSmall,
                                    color: color.grayscalePlacehold
                                )

                            DText(examinationData.examinationNumber)
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

                            ExpandableTextView(
                                text: examinationData.examinationDescription,
                                backgroundColor: color.grayscaleBackgroundWeak
                            )
                            .padding(.bottom, size.s8)

                            if let patientComplaints = examinationData.patientComplaints,
                               !patientComplaints.isEmpty
                            {
                                DText(.scanPatientComplaintsLabel)
                                    .dStyle(
                                        font: typography.linkSmall,
                                        color: color.grayscalePlacehold
                                    )

                                ExpandableTextView(
                                    text: patientComplaints,
                                    backgroundColor: color.grayscaleBackgroundWeak
                                )
                                .padding(.bottom, size.s8)
                                .transition(.opacity)
                            }

                            DText(.reportActualModelResponseTitle)
                                .dStyle(
                                    font: typography.linkLarge
                                )
                                .padding(.top, size.s16)
                                .padding(.horizontal, size.s8)
                                .padding(.bottom, size.s16)

                            NeuralModelReportCardView(
                                report: report.actualModelReport,
                                onTapCopy: { viewModel.onTapCopy(report: report.actualModelReport) }
                            )
                            .padding(.top, toolbarInset)
                            .id(ReportDetailViewModel.actualModelReportCardScrollId(
                                toolbarInset: toolbarInset
                            ))
                            .padding(.top, -toolbarInset)
                            .padding(.bottom, size.s8)

                            NeuralModelCardView(
                                onTap: viewModel.onTapNeuralModelSelection
                            )
                            .padding(.bottom, size.s16)

                            NeuralModelSettingsCardView(
                                feature: .neuralModelSettings,
                                onTap: viewModel.onTapNeuralModelSettings
                            )

                            DButton(
                                image: .refresh,
                                title: .buttonRepeatGenerate,
                                action: {
                                    viewModel.onTapRepeatScan(
                                        proxy: proxy,
                                        toolbarInset: toolbarInset
                                    )
                                },
                                isLoading: viewModel.isLoading
                            )
                            .dStyle(.primaryButton)
                            .padding(.bottom, size.s16)

                            if !report.previousModelReports.isEmpty {
                                Group {
                                    DText(.reportPreviousModelResponsesTitle)
                                        .dStyle(
                                            font: typography.linkLarge
                                        )
                                        .padding(.top, size.s8)
                                        .padding(.horizontal, size.s8)
                                        .padding(.bottom, size.s16)

                                    ForEach(report.previousModelReports) { modelReport in
                                        NeuralModelReportCardView(
                                            report: modelReport,
                                            onTapCopy: { viewModel.onTapCopy(report: modelReport) }
                                        )
                                        .padding(.bottom, size.s8)
                                    }
                                }
                                .transition(.opacity)
                            }
                        }
                        .padding(.horizontal, size.s16)
                    }
                    .padding(.top, size.s16 + toolbarInset)
                    .padding(.bottom, size.s128)
                }
            }
        }
        .animation(
            theme.animation,
            value: viewModel.report.actualModelReport.id
        )
        .animation(
            theme.animation,
            value: viewModel.report.previousModelReports.map(\.id)
        )
        .onAppear(perform: viewModel.onAppear)
        .environmentObject(viewModel)
    }
}
