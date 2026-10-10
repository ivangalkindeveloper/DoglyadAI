import AVFAudio
import Foundation
import Speech

/// A bridge between the microphone and the `SFSpeechRecognizer` recognition task.
///
/// It solves two problems that cannot be solved in the controller:
///
/// 1. The `AVAudioEngine` tap fires on the audio thread while the task is recreated
/// by the main thread. Touching the current request directly from two threads is a
/// race: a buffer could land in an already finished request. Here the request
/// reference is guarded by a lock.
///
/// 2. The service finalizes the task itself once the duration limit is hit. While a
/// new one is being created, audio has nowhere to go — speech in that window used to
/// be lost. So the tail of the last few seconds is kept and poured into the new request.
final class DSpeechAudioRelay: @unchecked Sendable {
    /// How much audio is kept for the hand-off. A second covers the task recreation
    /// window; anything more only duplicates already recognized text.
    private static let replaySeconds: Double = 1.0

    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?

    /// A ring of pre-allocated buffers: allocations on the audio thread cause audio
    /// dropouts, so the memory is taken once at start.
    private var ring: [AVAudioPCMBuffer] = []
    private var ringWriteIndex = 0
    private var ringFilled = 0

    /// Allocates the ring for the microphone format. Call before installing the tap.
    func prepare(
        format: AVAudioFormat,
        bufferFrames: AVAudioFrameCount,
    ) {
        let framesPerSecond = format.sampleRate
        let slots = max(
            2,
            Int(
                (Self.replaySeconds * framesPerSecond / Double(
                    bufferFrames,
                )).rounded(
                    .up,
                ),
            ),
        )
        // The tap does not guarantee exactly `bufferFrames` per buffer, so allow slack.
        let capacity = bufferFrames * 2
        let buffers = (0 ..< slots).compactMap {
            _ in AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: capacity,
            )
        }

        lock.lock()
        defer { lock.unlock() }

        request = nil
        ring = buffers
        ringWriteIndex = 0
        ringFilled = 0
    }

    /// Called from the audio thread.
    func append(
        _ buffer: AVAudioPCMBuffer,
    ) {
        lock.lock()
        defer { lock.unlock() }

        request?.append(
            buffer,
        )
        remember(
            buffer,
        )
    }

    /// Attaches a new task and pours the accumulated tail into it so that words at
    /// the seam between tasks are not dropped.
    func attach(
        _ newRequest: SFSpeechAudioBufferRecognitionRequest,
    ) {
        lock.lock()
        defer { lock.unlock() }

        request = newRequest
        for buffer in orderedRingBuffers() {
            newRequest.append(
                buffer,
            )
        }
    }

    /// Detaches the request: microphone buffers stop reaching it.
    func detach() {
        lock.lock()
        defer { lock.unlock() }

        request = nil
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }

        request = nil
        ring = []
        ringWriteIndex = 0
        ringFilled = 0
    }

    /// Copies the buffer into the ring: the one delivered to the tap is reused by the
    /// engine right after the callback returns, so the reference itself cannot be kept.
    private func remember(
        _ buffer: AVAudioPCMBuffer,
    ) {
        guard !ring.isEmpty else { return }
        guard let source = buffer.floatChannelData else { return }

        let slot = ring[
            ringWriteIndex,
        ]
        guard let destination = slot.floatChannelData else { return }
        guard buffer.format.channelCount == slot.format.channelCount else { return }

        let frames = min(
            buffer.frameLength,
            slot.frameCapacity,
        )
        let bytes = Int(
            frames,
        ) * MemoryLayout<Float>.size
        for channel in 0 ..< Int(
            slot.format.channelCount,
        ) {
            memcpy(
                destination[
                    channel,
                ],
                source[
                    channel,
                ],
                bytes,
            )
        }
        slot.frameLength = frames

        ringWriteIndex = (ringWriteIndex + 1) % ring.count
        ringFilled = min(
            ringFilled + 1,
            ring.count,
        )
    }

    /// Ring buffers in chronological order — from the oldest to the freshest.
    private func orderedRingBuffers() -> [AVAudioPCMBuffer] {
        guard ringFilled > 0 else { return [] }

        let start = (ringWriteIndex - ringFilled + ring.count) % ring.count

        return (0 ..< ringFilled).map { ring[
            (start + $0) % ring.count,
        ] }
    }
}
