import AVFoundation
import Foundation
import WhisperKit

/// Keeps the application's microphone and Bluetooth setup when WhisperKit starts capture.
final class DSpeechWhisperKitAudioProcessor: AudioProcessing, @unchecked Sendable {
    // The tap owns SDK buffers. The SDK's decoder reads these locked snapshots;
    // engine start/stop is serialized independently from audio callbacks.
    private let processor = AudioProcessor()
    private let engineLock = NSLock()
    private let samplesLock = NSLock()
    private var recordedSamples: ContiguousArray<Float> = []
    private var recordedEnergy: [Float] = []

    var isRecording: Bool { engineLock.withLock { processor.audioEngine?.isRunning == true } }
    var audioSamples: ContiguousArray<Float> { samplesLock.withLock { recordedSamples } }
    var relativeEnergy: [Float] { samplesLock.withLock { recordedEnergy } }
    var relativeEnergyWindow: Int {
        get { engineLock.withLock { processor.relativeEnergyWindow } }
        set { engineLock.withLock { processor.relativeEnergyWindow = newValue } }
    }

    func startRecordingLive(
        inputDeviceID: DeviceID?,
        callback: (([Float]) -> Void)?,
    ) throws {
        engineLock.lock()
        defer { engineLock.unlock() }
        try Task.checkCancellation()
        try DSpeechAudioSession.activate()
        samplesLock.withLock {
            recordedSamples = []
            recordedEnergy = []
        }
        processor.audioSamples = []
        processor.audioEnergy = []
        processor.audioBufferCallback = { [weak self] buffer in
            self?.receiveSamples(
                buffer,
                callback: callback,
            )
        }
        processor.audioEngine = try processor.setupEngine(
            inputDeviceID: inputDeviceID,
        )
    }

    func stopRecording() {
        engineLock.withLock {
            processor.stopRecording()
            processor.audioBufferCallback = nil
        }
    }

    func pauseRecording() {
        engineLock.withLock { processor.pauseRecording() }
    }

    func resumeRecordingLive(
        inputDeviceID: DeviceID?,
        callback: (([Float]) -> Void)?,
    ) throws {
        engineLock.lock()
        defer { engineLock.unlock() }
        try Task.checkCancellation()
        try DSpeechAudioSession.activate()
        if let callback {
            processor.audioBufferCallback = { [weak self] buffer in
                self?.receiveSamples(
                    buffer,
                    callback: callback,
                )
            }
        }
        if let engine = processor.audioEngine {
            try engine.start()
        } else {
            processor.audioEngine = try processor.setupEngine(
                inputDeviceID: inputDeviceID,
            )
        }
    }

    func startStreamingRecordingLive(
        inputDeviceID: DeviceID?,
    ) -> (AsyncThrowingStream<[Float], Error>, AsyncThrowingStream<[Float], Error>.Continuation) {
        let (stream, continuation) = AsyncThrowingStream<[Float], Error>.makeStream()
        continuation.onTermination = { [weak self] _ in self?.stopRecording() }
        do {
            try startRecordingLive(
                inputDeviceID: inputDeviceID,
                callback: { continuation.yield(
                    $0,
                ) },
            )
        } catch {
            continuation.finish(
                throwing: error,
            )
        }
        return (stream, continuation)
    }

    func purgeAudioSamples(
        keepingLast keep: Int,
    ) {
        samplesLock.withLock {
            let count = max(
                0,
                keep,
            )
            guard count > 0 else {
                recordedSamples = []
                recordedEnergy = []
                return
            }
            if recordedSamples.count > count { recordedSamples.removeFirst(
                recordedSamples.count - count,
            ) }
        }
    }

    func padOrTrim(
        fromArray audioArray: [Float],
        startAt startIndex: Int,
        toLength frameLength: Int,
    ) -> (any AudioProcessorOutputType)? {
        processor.padOrTrim(
            fromArray: audioArray,
            startAt: startIndex,
            toLength: frameLength,
        )
    }

    static func loadAudio(
        fromPath path: String,
        channelMode: ChannelMode,
        startTime: Double?,
        endTime: Double?,
        maxReadFrameSize: AVAudioFrameCount?,
    ) throws -> AVAudioPCMBuffer {
        try AudioProcessor.loadAudio(
            fromPath: path,
            channelMode: channelMode,
            startTime: startTime,
            endTime: endTime,
            maxReadFrameSize: maxReadFrameSize,
        )
    }

    static func loadAudio(
        at paths: [String],
        channelMode: ChannelMode,
    ) async -> [Result<[Float], Error>] {
        await AudioProcessor.loadAudio(
            at: paths,
            channelMode: channelMode,
        )
    }

    private func receiveSamples(
        _ buffer: [Float],
        callback: (([Float]) -> Void)?,
    ) {
        samplesLock.withLock {
            recordedSamples.append(
                contentsOf: buffer,
            )
            recordedEnergy.append(
                processor.audioEnergy.last?.rel ?? 0,
            )
        }
        // The complete recording lives in recordedSamples; the SDK's capture
        // buffer is not read by the decoder and need not keep a second copy.
        processor.purgeAudioSamples(
            keepingLast: 0,
        )
        callback?(
            buffer,
        )
    }
}
