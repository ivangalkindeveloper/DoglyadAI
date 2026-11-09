import DoglyadUI
import SwiftUI

struct PaywallSegmentTypeView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: PaywallViewModel
    let state: PaywallContentState

    var body: some View {
        DSegment(
            currentValue: state.selectedType,
            items: state.tiers.map { tier in
                DSegmentItem(
                    value: tier.id,
                    title: LocalizedStringResource(
                        "\(tier.title)",
                    ),
                ) {
                    viewModel.onSelectType(
                        tier.id,
                    )
                }
            },
            isDisabled:
            viewModel.isProcessing,
        )
        .padding(
            size.s4,
        )
        .background(
            DCardBackground(
                cornerRadius: size.s64,
                color: color.grayscaleInput,
            ),
        )
    }
}
