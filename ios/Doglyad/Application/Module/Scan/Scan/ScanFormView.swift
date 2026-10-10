import DoglyadUI
import SwiftUI

struct ScanFormView: DView {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @EnvironmentObject private var viewModel: ScanViewModel
    let focus: FocusState<ScanViewModel.Focus?>.Binding

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: .zero,
        ) {
            DTextField(
                controller: viewModel.examinationNumberController,
                focus: DTextFieldFocus(
                    value: .examinationNumber,
                    state: focus,
                ),
                title: l10n[
                    .scanExaminationNumberLabel,
                ],
                placeholder: l10n[
                    .scanExaminationNumberPlaceholder,
                ],
                mode: DTextFieldSingleLineMode(
                    submitLabel: .next,
                ),
                keyboardType: .default,
            )
            .id(
                ScanViewModel.Focus.examinationNumber,
            )
            .padding(
                .vertical,
                size.s4,
            )

            DTextField(
                controller: viewModel.patientNameController,
                focus: DTextFieldFocus(
                    value: .patientName,
                    state: focus,
                ),
                title: l10n[
                    .scanPatientNameLabel,
                ],
                placeholder: l10n[
                    .scanPatientNamePlaceholder,
                ],
                mode: DTextFieldSingleLineMode(
                    submitLabel: .next,
                ),
                keyboardType: .default,
            )
            .id(
                ScanViewModel.Focus.patientName,
            )
            .padding(
                .bottom,
                size.s4,
            )

            DSegment<PatientGender>(
                currentValue: viewModel.patientGender,
                items: [
                    DSegmentItem<PatientGender>(
                        value: .male,
                        title: l10n[
                            .scanGenderMaleLabel,
                        ],
                    ) {
                        viewModel.onTapPatientGender(
                            value: .male,
                        )
                    },
                    DSegmentItem<PatientGender>(
                        value: .female,
                        title: l10n[
                            .scanGenderFemaleLabel,
                        ],
                    ) {
                        viewModel.onTapPatientGender(
                            value: .female,
                        )
                    },
                ],
            )
            .padding(
                .bottom,
                size.s4,
            )

            DateOfBirthCardView(
                date: viewModel.patientDateOfBirth,
                action: viewModel.onTapPatientDateOfBirth,
            )
            .contentTransition(
                .opacity,
            )
            .animation(
                theme.animation,
                value: viewModel.patientDateOfBirth,
            )
            .padding(
                .bottom,
                size.s4,
            )

            DTextField(
                controller: viewModel.patientHeightCMController,
                focus: DTextFieldFocus(
                    value: .patientHeightCM,
                    state: focus,
                ),
                title: l10n[
                    .scanPatientHeightCMLabel,
                ],
                placeholder: l10n[
                    .scanNumberPlaceholder,
                ],
                mode: DTextFieldSingleLineMode(
                    submitLabel: .next,
                ),
                keyboardType: .decimalPad,
            )
            .id(
                ScanViewModel.Focus.patientHeightCM,
            )
            .padding(
                .bottom,
                size.s4,
            )

            DTextField(
                controller: viewModel.patientWeightKGController,
                focus: DTextFieldFocus(
                    value: .patientWeightKG,
                    state: focus,
                ),
                title: l10n[
                    .scanPatientWeightKGLabel,
                ],
                placeholder: l10n[
                    .scanNumberPlaceholder,
                ],
                mode: DTextFieldSingleLineMode(
                    submitLabel: .next,
                ),
                keyboardType: .decimalPad,
            )
            .id(
                ScanViewModel.Focus.patientWeightKG,
            )
            .padding(
                .bottom,
                size.s4,
            )

            DTextField(
                controller: viewModel.patientComplaintsController,
                focus: DTextFieldFocus(
                    value: .patientComplaints,
                    state: focus,
                ),
                title: l10n[
                    .scanPatientComplaintsLabel,
                ],
                placeholder: l10n[
                    .scanPatientComplaintsPlaceholder,
                ],
                mode: DTextFieldMultiLineMode(),
                keyboardType: .default,
            )
            .id(
                ScanViewModel.Focus.patientComplaints,
            )
            .padding(
                .bottom,
                size.s4,
            )

            DTextField(
                controller: viewModel.examinationDescriptionController,
                focus: DTextFieldFocus(
                    value: .examinationDescription,
                    state: focus,
                ),
                title: l10n[
                    .scanExaminationDescriptionLabel,
                ],
                placeholder: l10n[
                    .scanExaminationDescriptionPlaceholder,
                ],
                mode: DTextFieldMultiLineMode(),
                keyboardType: .default,
            )
            .id(
                ScanViewModel.Focus.examinationDescription,
            )
            .padding(
                .bottom,
                size.s16,
            )

            ScanTemplateCardView()
                .padding(
                    .bottom,
                    size.s16,
                )

            NeuralModelCardView(
                onTap: viewModel.onTapNeuralModelSelection,
            )
            .padding(
                .bottom,
                size.s16,
            )

            NeuralModelSettingsCardView(
                feature: .neuralModelSettings,
                onTap: viewModel.onTapNeuralModelSettings,
            )

            DButton(
                title: l10n[
                    .buttonClear,
                ],
                action: viewModel.onTapClear,
            )
            .dStyle(
                .primaryText,
            )

            if viewModel.isFillDevelopmentButtonVisible {
                DButton(
                    title: l10n[
                        .buttonFillDevelopment,
                    ],
                    action: viewModel.onTapFillDevelopment,
                )
                .dStyle(
                    .primaryText,
                )
            }
        }
        .padding(
            .horizontal,
            size.s16,
        )
    }
}
