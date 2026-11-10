import DoglyadUI
import SwiftUI

struct ScanFormView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: ScanViewModel
    let focus: FocusState<ScanFocus?>.Binding
    var isDisabled: Bool = false

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: .zero,
        ) {
            DTextField(
                inputTextController: viewModel.examinationNumberTextController,
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
                isDisabled: isDisabled,
                accessibilityIdentifier: "scan.examinationNumber",
            )
            .id(
                ScanFocus.examinationNumber,
            )
            .padding(
                .vertical,
                size.s4,
            )

            DTextField(
                inputTextController: viewModel.patientNameTextController,
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
                isDisabled: isDisabled,
                accessibilityIdentifier: "scan.patientName",
            )
            .id(
                ScanFocus.patientName,
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
                isDisabled: isDisabled,
                accessibilityIdentifier: "scan.patientGender.\(viewModel.patientGender.rawValue)",
            )
            .padding(
                .bottom,
                size.s4,
            )

            ScanDateOfBirthCardView(
                isDisabled: isDisabled,
            )
            .contentTransition(
                .opacity,
            )
            .padding(
                .bottom,
                size.s4,
            )

            DTextField(
                inputTextController: viewModel.patientHeightCMTextController,
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
                isDisabled: isDisabled,
                accessibilityIdentifier: "scan.patientHeightCM",
            )
            .id(
                ScanFocus.patientHeightCM,
            )
            .padding(
                .bottom,
                size.s4,
            )

            DTextField(
                inputTextController: viewModel.patientWeightKGTextController,
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
                isDisabled: isDisabled,
                accessibilityIdentifier: "scan.patientWeightKG",
            )
            .id(
                ScanFocus.patientWeightKG,
            )
            .padding(
                .bottom,
                size.s4,
            )

            DTextField(
                inputTextController: viewModel.patientComplaintsTextController,
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
                isDisabled: isDisabled,
                accessibilityIdentifier: "scan.patientComplaints",
            )
            .id(
                ScanFocus.patientComplaints,
            )
            .padding(
                .bottom,
                size.s4,
            )

            DTextField(
                inputTextController: viewModel.examinationDescriptionTextController,
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
                isDisabled: isDisabled,
                accessibilityIdentifier: "scan.examinationDescription",
            )
            .id(
                ScanFocus.examinationDescription,
            )
            .padding(
                .bottom,
                size.s4,
            )

            DToggleCard(
                title: l10n[
                    .scanPatientPreparedForExaminationLabel,
                ],
                isOn: .constant(
                    viewModel.isPatientPreparedForExamination,
                ),
                action: viewModel.togglePatientPreparedForExamination,
                isDisabled: isDisabled,
                accessibilityIdentifier: "scan.isPatientPreparedForExamination",
            )
            .padding(
                .bottom,
                size.s16,
            )

            ScanTemplateCardView(
                isDisabled: isDisabled,
            )
            .padding(
                .bottom,
                size.s16,
            )

            NeuralModelCardView(
                modelTitle: viewModel.selectedNeuralModelTitle,
                availableRequestCount: viewModel.availableRequestCount,
                onTap: viewModel.onTapNeuralModelSelection,
                isDisabled: isDisabled,
            )
            .padding(
                .bottom,
                size.s16,
            )

            SettingsAICardView(
                settings: viewModel.settingsAI,
                onTap: viewModel.onTapSettingsAI,
                isDisabled: isDisabled,
            )

            DButton(
                title: l10n[
                    .buttonClear,
                ],
                action: viewModel.onTapClear,
                isDisabled: isDisabled,
                accessibilityIdentifier: "scan.clear",
            )
            .dStyle(
                .primaryText,
            )

            switch viewModel.environmentType {
            case .development:
                DButton(
                    title: l10n[
                        .scanFillDevelopmentButton,
                    ],
                    action: viewModel.onTapFillDevelopment,
                    isDisabled: isDisabled,
                )
                .dStyle(
                    .primaryText,
                )
            case .production: EmptyView()
            }
        }
        .padding(
            .horizontal,
            size.s16,
        )
    }
}
