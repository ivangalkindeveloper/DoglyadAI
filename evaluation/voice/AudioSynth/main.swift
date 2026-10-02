import AVFoundation
import Foundation

private struct Job: Decodable {
    let id: String
    let locale: String
    let spokenText: String
    let outputPath: String
}

private struct Result: Encodable {
    let id: String
    let status: String
    let voiceIdentifier: String?
    let reason: String?
}

private final class Writer {
    private let lock = NSLock()
    private var file: AVAudioFile?
    private var isFinished = false
    private var failure: String?
    private var frames: Int64 = 0

    var finished: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isFinished
    }

    var error: String? {
        lock.lock()
        defer { lock.unlock() }
        return failure
    }

    var frameCount: Int64 {
        lock.lock()
        defer { lock.unlock() }
        return frames
    }

    func close() {
        lock.lock()
        defer { lock.unlock() }
        // AVAudioFile writes the final WAV header when its last reference goes away.
        // The synthesizer callback may retain Writer after this function returns.
        file = nil
    }

    func receive(_ buffer: AVAudioBuffer, at url: URL) {
        lock.lock()
        defer { lock.unlock() }
        guard let buffer = buffer as? AVAudioPCMBuffer else {
            failure = "Synthesis returned a non-PCM buffer"
            isFinished = true
            return
        }
        guard buffer.frameLength > 0 else {
            isFinished = true
            return
        }
        guard failure == nil else { return }

        do {
            if file == nil {
                let settings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVSampleRateKey: buffer.format.sampleRate,
                    AVNumberOfChannelsKey: buffer.format.channelCount,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: false,
                    AVLinearPCMIsNonInterleaved: false,
                ]
                file = try AVAudioFile(forWriting: url, settings: settings)
            }
            try file?.write(from: buffer)
            frames += Int64(buffer.frameLength)
        } catch {
            failure = String(describing: error)
            isFinished = true
        }
    }
}

private func synthesize(_ job: Job) -> Result {
    let language = job.locale == "ru" ? "ru-RU" : "en-US"
    let voices = AVSpeechSynthesisVoice.speechVoices()
        .filter { $0.language == language }
        .sorted { left, right in
            let leftCompact = left.identifier.contains(".compact.")
            let rightCompact = right.identifier.contains(".compact.")
            if leftCompact != rightCompact { return leftCompact }
            return left.identifier < right.identifier
        }
    guard let voice = voices.first else {
        return Result(id: job.id, status: "skipped", voiceIdentifier: nil, reason: "No installed voice for \(language)")
    }

    let url = URL(fileURLWithPath: job.outputPath)
    do {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    } catch {
        return Result(id: job.id, status: "failed", voiceIdentifier: voice.identifier, reason: String(describing: error))
    }

    let utterance = AVSpeechUtterance(string: job.spokenText)
    utterance.voice = voice
    utterance.rate = 0.5
    let writer = Writer()
    let synthesizer = AVSpeechSynthesizer()
    synthesizer.write(utterance) { buffer in
        writer.receive(buffer, at: url)
    }

    let deadline = Date().addingTimeInterval(120)
    while !writer.finished && Date() < deadline {
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    }
    if !writer.finished {
        synthesizer.stopSpeaking(at: .immediate)
        writer.close()
        return Result(id: job.id, status: "failed", voiceIdentifier: voice.identifier, reason: "Synthesis timed out")
    }
    writer.close()
    if let error = writer.error {
        return Result(id: job.id, status: "failed", voiceIdentifier: voice.identifier, reason: error)
    }
    guard writer.frameCount > 0 else {
        return Result(id: job.id, status: "failed", voiceIdentifier: voice.identifier, reason: "Synthesis produced no audio")
    }
    return Result(id: job.id, status: "ok", voiceIdentifier: voice.identifier, reason: nil)
}

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: voice-audio-synth jobs.json results.jsonl\n", stderr)
    exit(2)
}

do {
    let jobs = try JSONDecoder().decode([Job].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
    let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
    FileManager.default.createFile(atPath: outputURL.path, contents: nil)
    let handle = try FileHandle(forWritingTo: outputURL)
    defer { try? handle.close() }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    for (index, job) in jobs.enumerated() {
        let result = synthesize(job)
        var data = try encoder.encode(result)
        data.append(0x0A)
        try handle.write(contentsOf: data)
        print("\(index + 1)/\(jobs.count) \(job.id): \(result.status)")
    }
} catch {
    fputs("Audio synthesis failed: \(error)\n", stderr)
    exit(1)
}
