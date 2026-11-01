import DoglyadUI
import SwiftUI

struct ScanSpeechButtonView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: ScanViewModel

    var body: some View {
        switch viewModel.subscriptionAvailability(
            of: .formCompletionViaMicrophone,
        ) {
        case .available, .offered:
            ScanSpeechStateButtonView()
        case .unavailable: EmptyView()
        }
    }
}
