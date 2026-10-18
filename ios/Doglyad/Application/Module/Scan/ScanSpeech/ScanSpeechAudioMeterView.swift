import DoglyadUI
import SwiftUI

struct ScanSpeechAudioMeterView: View {
    @EnvironmentObject private var viewModel: ScanSpeechViewModel

    var body: some View {
        DAudioMeter(
            level: viewModel.speechController.audioMeter,
        )
    }
}
