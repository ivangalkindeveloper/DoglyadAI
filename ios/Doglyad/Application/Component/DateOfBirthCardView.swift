import DoglyadUI
import Foundation
import SwiftUI

struct DateOfBirthCardView: DView {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    let date: Date
    let action: () -> Void

    init(
        date: Date,
        action: @escaping () -> Void,
    ) {
        self.date = date
        self.action = action
    }

    var body: some View {
        Button(
            action: action,
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
                    "(\(ageCount()) \(String(localized: l10n[.scanPatientDateOfBirthAgeLabel])))",
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
        .buttonStyle(
            DButtonStyle(
                .chip,
            ),
        )
    }
}

private extension DateOfBirthCardView {
    func ageCount() -> Int {
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.year],
            from: date,
            to: Date(),
        ).year!
    }
}

#Preview {
    @Previewable @State var date = {
        let dateString = "06.12.2000"
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        formatter.locale = Locale(
            identifier: "ru_RU",
        )
        return formatter.date(
            from: dateString,
        )!
    }()

    DateOfBirthCardView(
        date: date,
        action: {},
    )
    .padding()
    .dThemeWrapper()
    .localization(
        DependencyContainer.previewable.l10n,
    )
}
