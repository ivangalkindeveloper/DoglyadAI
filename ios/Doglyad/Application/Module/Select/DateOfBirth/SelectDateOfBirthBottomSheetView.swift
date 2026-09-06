import DoglyadUI
import SwiftUI

struct SelectDateOfBirthBottomSheetView: View {
    @EnvironmentObject private var theme: DTheme
    private var size: DSize { theme.size }

    @StateObject var viewModel: SelectDateOfBirthViewModel

    var body: some View {
        DBottomSheet(
            title: .selectDateOfBirthTitle,
            fraction: 0.5
        ) { toolbarHeight, _ in
            VStack(
                spacing: .zero
            ) {
                DatePicker(
                    .selectDateOfBirthTitle,
                    selection: $viewModel.date,
                    in: viewModel.fromDate ... viewModel.toDate,
                    displayedComponents: [.date]
                )
                .labelsHidden()
                .datePickerStyle(.wheel)
                .colorScheme(.light)
                .padding(.bottom, size.s16)

                Spacer()
            }
            .padding(size.s16)
            .padding(.top, toolbarHeight)
        } bottom: {
            DButton(
                title: .buttonSelect,
                action: viewModel.onTapSelect
            )
            .dStyle(.primaryButton)
            .padding(.horizontal, size.s16)
        }
        .onAppear(perform: viewModel.onAppear)
    }
}
