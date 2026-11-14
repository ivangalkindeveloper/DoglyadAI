import DoglyadUI
import Foundation
import SwiftUI

struct ScanDateOfBirthCardView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: ScanViewModel

    private var date: Date {
        viewModel.patientDateOfBirth
    }

    var isDisabled: Bool = false

    init(
        isDisabled: Bool = false,
    ) {
        self.isDisabled = isDisabled
    }

    var body: some View {
        DCard(
            action: viewModel.onTapPatientDateOfBirth,
            content: {
                HStack(
                    spacing: .zero,
                ) {
                    DText(
                        "\(String(localized: l10n[.scanPatientDateOfBirthLabel])): \(date.localized(locale: l10n.locale))",
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
            },
            isDisabled: isDisabled,
        )
    }
}
