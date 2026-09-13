import DoglyadUI
import SwiftUI

struct ScanSpeechAudioMeterView: View {
    @EnvironmentObject private var theme: DTheme
    private var color: DColor { theme.color }
    private var size: DSize { theme.size }

    let level: Float

    /// A fixed bar profile. Heights used to come from `CGFloat.random` right inside
    /// `body`, so the meter was rebuilt at random on every redraw: the animation
    /// reflected generator noise rather than the physician's voice.
    private static let profile: [CGFloat] = [0.3, 0.55, 0.8, 1.0, 0.7, 0.85, 1.0, 0.75, 0.5, 0.3]
    private static let minimumHeight: CGFloat = 4

    var body: some View {
        HStack(
            spacing: size.s4
        ) {
            ForEach(Array(Self.profile.enumerated()), id: \.offset) { _, weight in
                Capsule()
                    .fill(color.grayscaleBackgroundWeak)
                    .frame(
                        width: size.s4,
                        height: height(for: weight)
                    )
            }
        }
        .frame(
            height: size.s24
        )
        .animation(
            theme.animation,
            value: level
        )
    }

    private func height(
        for weight: CGFloat
    ) -> CGFloat {
        let clamped = CGFloat(min(max(level, 0), 1))
        let range = size.s24 - Self.minimumHeight

        return Self.minimumHeight + range * weight * clamped
    }
}
