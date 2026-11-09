import DoglyadUI
import SwiftUI

struct PatientConsentCheckboxView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: PatientConsentViewModel

    var body: some View {
        HStack(
            spacing: size.s16,
        ) {
            DCheckbox(
                isChecked: Binding(
                    get: {
                        viewModel.state.isDoNotAskAgain
                    },
                    set: viewModel.onDoNotAskAgainChanged,
                ),
                accessibilityIdentifier: viewModel.state.isDoNotAskAgain ? "patientConsent.doNotAsk.selected" : "patientConsent.doNotAsk.unselected",
            )

            DText(
                l10n[
                    .patientConsentDoNotAskAgainLabel,
                ],
            )
            .dStyle(
                font: typography.textSmall,
                color: color.grayscaleHeader,
                alignment: .leading,
            )
        }
        .frame(
            maxWidth: .infinity,
            alignment: .center,
        )
    }
}
