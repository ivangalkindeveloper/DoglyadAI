import AVFoundation
import Foundation

final class DSpeechTOneAudioCapture: DSpeechTOneAudioCaptureProtocol, @unchecked Sendable {
    static let maxAudioBytes = 8000 * 2 * 300
    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private let meter: DSpeechAudioMeter
    private let onEnd: @Sendable (DSpeechCompletion) -> Void
    private var converter: AVAudioConverter?
    private var audio = Data()
    private var isAccepting = false
    private var isTapInstalled = false

    init(
        meter: DSpeechAudioMeter,
        onEnd: @escaping @Sendable (DSpeechCompletion) -> Void,
    ) {
        self.meter = meter
        self.onEnd = onEnd
    }

    func start() throws {
        try DSpeechAudioSession.activate()
        let input = engine.inputNode
        try input.setVoiceProcessingEnabled(
            true,
        )
        let format = input.outputFormat(
            forBus: 0,
        )
        guard format.isValidForCapture,
              let output = AVAudioFormat(
                  commonFormat: .pcmFormatInt16,
                  sampleRate: 8000,
                  channels: 1,
                  interleaved: true,
              ),
              let converter = AVAudioConverter(
                  from: format,
                  to: output,
              )
        else {
            throw DSpeechError.unavailable
        }
        self.converter = converter
        converter.primeMethod = .none
        lock.lock()
        isAccepting = true
        lock.unlock()
        input.installTap(
            onBus: 0,
            bufferSize: 2048,
            format: format,
        ) { [weak self] buffer, _ in
            self?.append(
                buffer,
            )
        }
        isTapInstalled = true
        engine.prepare()
        try engine.start()
    }

    func stop() -> Data {
        engine.stop()
        if isTapInstalled {
            engine.inputNode.removeTap(
                onBus: 0,
            )
            isTapInstalled = false
        }
        lock.lock()
        if isAccepting, let converter,
           let output = AVAudioPCMBuffer(
               pcmFormat: converter.outputFormat,
               frameCapacity: 256,
           )
        {
            var error: NSError?
            _ = converter.convert(
                to: output,
                error: &error,
            ) { _, status in
                status.pointee = .endOfStream
                return nil
            }
            appendPCM(
                output,
            )
        }
        isAccepting = false
        let result = audio
        audio = Data()
        lock.unlock()
        meter.reset()
        DSpeechAudioSession.deactivate()
        return result
    }

    private func append(
        _ buffer: AVAudioPCMBuffer,
    ) {
        lock.lock()
        guard isAccepting, let converter else {
            lock.unlock()
            return
        }
        let capacity = AVAudioFrameCount(
            ceil(
                Double(
                    buffer.frameLength,
                ) * 8000 / buffer.format.sampleRate,
            ),
        ) + 32
        guard let output = AVAudioPCMBuffer(
            pcmFormat: converter.outputFormat,
            frameCapacity: capacity,
        ) else {
            isAccepting = false
            lock.unlock()
            onEnd(
                .failed,
            )
            return
        }
        var isConsumed = false
        var error: NSError?
        let status = converter.convert(
            to: output,
            error: &error,
        ) { _, inputStatus in
            inputStatus.pointee = isConsumed ? .noDataNow : .haveData
            defer {
                isConsumed = true
            }
            return isConsumed ? nil : buffer
        }
        if status == .error {
            isAccepting = false
            lock.unlock()
            onEnd(
                .failed,
            )
            return
        }
        appendPCM(
            output,
        )
        let isAtLimit = audio.count >= Self.maxAudioBytes
        if isAtLimit {
            isAccepting = false
        }
        lock.unlock()
        meter.process(
            buffer,
        )
        if isAtLimit {
            onEnd(
                .timedOut,
            )
        }
    }

    private func appendPCM(
        _ buffer: AVAudioPCMBuffer,
    ) {
        guard let samples = buffer.int16ChannelData?[
            0,
        ] else {
            return
        }
        let count = min(
            Int(
                buffer.frameLength,
            ) * 2,
            Self.maxAudioBytes - audio.count,
        )
        audio.append(
            UnsafeRawPointer(
                samples,
            ).assumingMemoryBound(
                to: UInt8.self,
            ),
            count: count,
        )
    }
}
