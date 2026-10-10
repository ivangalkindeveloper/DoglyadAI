import DoglyadUI
import SwiftUI

struct SelectDateOfBirthBottomSheetView: DView {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: SelectDateOfBirthViewModel

    var body: some View {
        DBottomSheet(
            title: l10n[
                .selectDateOfBirthTitle,
            ],
            fraction: 0.5,
        ) { toolbarHeight, _ in
            VStack(
                spacing: .zero,
            ) {
                DatePicker(
                    l10n[
                        .selectDateOfBirthTitle,
                    ],
                    selection: $viewModel.date,
                    in: viewModel.fromDate ... viewModel.toDate,
                    displayedComponents: [.date],
                )
                .labelsHidden()
                .datePickerStyle(
                    .wheel,
                )
                .colorScheme(
                    .light,
                )
                .padding(
                    .bottom,
                    size.s16,
                )

                Spacer()
            }
            .padding(
                size.s16,
            )
            .padding(
                .top,
                toolbarHeight,
            )
        } bottom: {
            DButton(
                title: l10n[
                    .buttonSelect,
                ],
                action: viewModel.onTapSelect,
            )
            .dStyle(
                .primaryButton,
            )
            .padding(
                .horizontal,
                size.s16,
            )
        }
        .onAppear(
            perform: viewModel.onAppear,
        )
    }
}
