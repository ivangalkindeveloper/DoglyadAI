import DoglyadUI
import SwiftUI

struct UserSettingsToggleView: DView {
    @EnvironmentObject var theme: DTheme
    let title: LocalizedStringResource
    let description: LocalizedStringResource
    @Binding var isOn: Bool
    let action: () -> Void

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: size.s4,
        ) {
            DButtonCard(
                action: action,
            ) {
                HStack {
                    DText(
                        title,
                    ).dStyle(
                        font: typography.linkSmall,
                    )
                    Spacer(
                        minLength: size.s16,
                    )
                    DToggle(
                        title,
                        isOn: $isOn,
                    )
                    .labelsHidden()
                    .toggleStyle(
                        .switch,
                    )
                    .allowsHitTesting(
                        false,
                    )
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading,
                )
                .foregroundStyle(
                    color.grayscaleHeader,
                )
            }
            .accessibilityLabel(
                Text(
                    title,
                ),
            )

            DText(
                description,
            )
            .dStyle(
                font: typography.textXSmall,
                color: color.grayscalePlacehold,
            )
            .padding(
                .horizontal,
                size.s8,
            )
        }
    }
}
