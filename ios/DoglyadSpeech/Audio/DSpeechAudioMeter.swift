import Accelerate
import AVFAudio
import Foundation

/// Computes the microphone level for the meter on the dictation screen.
///
/// It lives on the audio thread, so RMS is taken via `vDSP` straight over the
/// buffer pointer — no copy into an `Array` and no intermediate `map`/`reduce`:
/// allocations in the tap callback cause audio dropouts, and therefore lost words.
///
/// The level is published not per buffer (there are about fifty per second) but on
/// a timer: the meter is happy with ~20 frames, while every `@Published` update
/// drags a redraw of the whole dictation screen along with it.
final class DSpeechAudioMeter: @unchecked Sendable {
    /// Level publishing step — 20 frames per second.
    private static let publishInterval: TimeInterval = 0.05
    /// The weight of the new value in the smoothing. Without it the meter jitters on
    /// every syllable; with it, it follows loudness smoothly.
    private static let smoothing: Float = 0.4
    /// Lifts RMS into the meter's range: handheld speech rarely exceeds 0.07.
    private static let gain: Float = 15

    private let lock = NSLock()
    private var level: Float = 0
    private var lastPublishUptime: TimeInterval = 0
    private let onLevel: @Sendable (Float) -> Void

    init(
        onLevel: @escaping @Sendable (Float) -> Void,
    ) {
        self.onLevel = onLevel
    }

    /// Called from the audio thread.
    func process(
        _ buffer: AVAudioPCMBuffer,
    ) {
        guard buffer.frameLength > 0 else { return }
        guard let channel = buffer.floatChannelData?[
            0,
        ] else { return }

        var rms: Float = 0
        vDSP_rmsqv(
            channel,
            1,
            &rms,
            vDSP_Length(
                buffer.frameLength,
            ),
        )
        let target = min(
            max(
                rms * Self.gain,
                0,
            ),
            1,
        )
        let now = ProcessInfo.processInfo.systemUptime

        lock.lock()
        level += (target - level) * Self.smoothing
        guard now - lastPublishUptime >= Self.publishInterval else {
            lock.unlock()
            return
        }
        lastPublishUptime = now
        let published = level
        lock.unlock()

        onLevel(
            published,
        )
    }

    func reset() {
        lock.lock()
        level = 0
        lastPublishUptime = 0
        lock.unlock()

        onLevel(
            0,
        )
    }
}
