import DoglyadUI
import SwiftUI

struct ScanFormView: DView {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject var theme: DTheme

    @EnvironmentObject private var viewModel: ScanViewModel
    let focus: FocusState<ScanViewModel.Focus?>.Binding

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: .zero
        ) {
            DTextField(
                controller: viewModel.patientNameController,
                focus: DTextFieldFocus(
                    value: .patientName,
                    state: focus
                ),
                title: .scanPatientNameLabel,
                placeholder: .scanPatientNamePlaceholder,
                mode: DTextFieldSingleLineMode(submitLabel: .next),
                keyboardType: .default
            )
            .id(ScanViewModel.Focus.patientName)
            .padding(.vertical, size.s4)

            DSegment<PatientGender>(
                currentValue: viewModel.patientGender,
                items: [
                    DSegmentItem<PatientGender>(
                        value: .male,
                        title: .scanGenderMaleLabel
                    ) {
                        viewModel.onTapPatientGender(value: .male)
                    },
                    DSegmentItem<PatientGender>(
                        value: .female,
                        title: .scanGenderFemaleLabel
                    ) {
                        viewModel.onTapPatientGender(value: .female)
                    },
                ]
            )
            .padding(.bottom, size.s4)

            DateOfBirthCardView(
                date: viewModel.patientDateOfBirth,
                action: viewModel.onTapPatientDateOfBirth
            )
            .padding(.bottom, size.s4)

            DTextField(
                controller: viewModel.patientHeightCMController,
                focus: DTextFieldFocus(
                    value: .patientHeightCM,
                    state: focus
                ),
                title: .scanPatientHeightCMLabel,
                placeholder: .scanNumberPlaceholder,
                mode: DTextFieldSingleLineMode(submitLabel: .next),
                keyboardType: .decimalPad
            )
            .id(ScanViewModel.Focus.patientHeightCM)
            .padding(.bottom, size.s4)

            DTextField(
                controller: viewModel.patientWeightKGController,
                focus: DTextFieldFocus(
                    value: .patientWeightKG,
                    state: focus
                ),
                title: .scanPatientWeightKGLabel,
                placeholder: .scanNumberPlaceholder,
                mode: DTextFieldSingleLineMode(submitLabel: .next),
                keyboardType: .decimalPad
            )
            .id(ScanViewModel.Focus.patientWeightKG)
            .padding(.bottom, size.s4)

            DTextField(
                controller: viewModel.patientComplaintController,
                focus: DTextFieldFocus(
                    value: .patientComplaint,
                    state: focus
                ),
                title: .scanPatientComplaintLabel,
                placeholder: .scanPatientComplaintPlaceholder,
                mode: DTextFieldMultiLineMode(),
                keyboardType: .default
            )
            .id(ScanViewModel.Focus.patientComplaint)
            .padding(.bottom, size.s4)

            DTextField(
                controller: viewModel.examinationDescriptionController,
                focus: DTextFieldFocus(
                    value: .examinationDescription,
                    state: focus
                ),
                title: .scanExaminationDescriptionLabel,
                placeholder: .scanExaminationDescriptionPlaceholder,
                mode: DTextFieldMultiLineMode(),
                keyboardType: .default
            )
            .id(ScanViewModel.Focus.examinationDescription)
            .padding(.bottom, size.s16)

            ScanTemplateCardView()
                .padding(.bottom, size.s16)

            NeuralModelCardView(
                onTap: viewModel.onTapNeuralModelSelection
            )
            .padding(.bottom, size.s16)

            NeuralModelSettingsCardView(
                feature: .neuralModelSettings,
                onTap: viewModel.onTapNeuralModelSettings
            )

            if container.environment.type == EnvironmentType.development {
                DButton(
                    title: .buttonFill,
                    action: viewModel.onTapFill
                )
                .dStyle(.primaryText)
            }
        }
        .padding(.horizontal, size.s16)
    }
}
