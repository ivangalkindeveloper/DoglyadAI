import DoglyadUI
import SwiftUI

struct PatientConsentBottomSheetView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: PatientConsentViewModel

    var body: some View {
        DInfoBottomSheet(
            fraction: 0.6,
            title: l10n[
                .patientConsentTitle,
            ],
            image: .doglyadQuestion,
            description: l10n[
                .patientConsentDescription,
            ],
            content: {
                PatientConsentCheckboxView()
            },
            buttonTitle: l10n[
                .buttonConfirm,
            ],
            action: viewModel.onTapConfirm,
        )
        .environmentObject(
            viewModel,
        )
        .onAppear(
            perform: viewModel.onAppear,
        )
        .onDisappear(
            perform: viewModel.onDisappear,
        )
    }
}
