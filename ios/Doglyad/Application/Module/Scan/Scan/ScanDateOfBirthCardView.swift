import DoglyadUI
import Foundation
import SwiftUI

struct ScanDateOfBirthCardView: DView {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @EnvironmentObject private var viewModel: ScanViewModel
    private var date: Date { viewModel.patientDateOfBirth }

    var body: some View {
        DButtonCard(
            style: .chip,

            action: viewModel.onTapPatientDateOfBirth,
        ) {
            HStack(
                spacing: .zero,
            ) {
                DText(
                    "\(String(localized: l10n[.scanPatientDateOfBirthLabel])): \(date.localized())",
                )
                .dStyle(
                    font: typography.linkSmall,
                )
                .padding(
                    .trailing,
                    size.s8,
                )

                DText(
                    "(\(viewModel.patientAge) \(String(localized: l10n[.scanPatientDateOfBirthAgeLabel])))",
                )
                .dStyle(
                    font: typography.textXSmall,
                    color: color.grayscalePlacehold,
                )
            }
            .frame(
                maxWidth: .infinity,
            )
        }
    }
}
