import AVFoundation
import Foundation
import Speech

private struct Job: Decodable {
    let id: String
    let locale: String
    let audioPath: String
    let contextualStrings: [String]
    let correctionStrings: [String]?
    let engine: String?
    let useHints: Bool?
    let isFarField: Bool?
}

private struct Result: Encodable {
    let id: String
    let status: String
    let rawText: String?
    let correctedText: String?
    let reason: String?
    let elapsedSeconds: Double?
}

private func collectFinalText(from transcriber: DictationTranscriber) async throws -> String {
    var text = AttributedString()
    for try await result in transcriber.results {
        if result.isFinal {
            text += result.text
        }
    }
    return String(text.characters)
}

private func recognize(_ job: Job) async -> Result {
    let started = Date()
    let requestedLocale = Locale(identifier: job.locale == "ru" ? "ru_RU" : "en_US")
    if job.engine == "sfSpeechRecognizer" {
        do {
            let result = try await DSpeechFileRecognizerSFSpeechRecognizer().transcribe(
                fileURL: URL(fileURLWithPath: job.audioPath),
                locale: requestedLocale,
                contextualStrings: job.contextualStrings,
                useHints: job.useHints ?? true
            )
            return Result(id: job.id, status: "ok", rawText: result.rawText,
                          correctedText: result.correctedText, reason: nil,
                          elapsedSeconds: Date().timeIntervalSince(started))
        } catch DSpeechFileTranscriberError.onDeviceRecognitionUnavailable {
            return Result(id: job.id, status: "skipped", rawText: nil, correctedText: nil,
                          reason: "Local SFSpeechRecognizer is unavailable", elapsedSeconds: nil)
        } catch {
            return Result(id: job.id, status: "failed", rawText: nil, correctedText: nil,
                          reason: String(describing: error), elapsedSeconds: Date().timeIntervalSince(started))
        }
    }
    guard job.engine == nil || job.engine == "speechAnalyzer" else {
        return Result(id: job.id, status: "failed", rawText: nil, correctedText: nil,
                      reason: "Unknown engine", elapsedSeconds: nil)
    }
    guard let resolvedLocale = await DictationTranscriber.supportedLocale(equivalentTo: requestedLocale) else {
        return Result(id: job.id, status: "skipped", rawText: nil, correctedText: nil,
                      reason: "DictationTranscriber does not support \(requestedLocale.identifier)", elapsedSeconds: nil)
    }
    let installed = await DictationTranscriber.installedLocales
    guard installed.contains(where: { $0.identifier(.bcp47) == resolvedLocale.identifier(.bcp47) }) else {
        return Result(id: job.id, status: "skipped", rawText: nil, correctedText: nil,
                      reason: "DictationTranscriber asset is not installed for \(resolvedLocale.identifier)", elapsedSeconds: nil)
    }

    var contentHints: Set<DictationTranscriber.ContentHint> = []
    if job.isFarField == true {
        contentHints.insert(.farField)
    }
    let transcriber = DictationTranscriber(
        locale: resolvedLocale,
        contentHints: contentHints,
        transcriptionOptions: [.punctuation],
        reportingOptions: [.volatileResults],
        attributeOptions: []
    )
    let analyzer = SpeechAnalyzer(modules: [transcriber])
    do {
        if job.useHints ?? true, !job.contextualStrings.isEmpty {
            let context = AnalysisContext()
            context.contextualStrings[.general] = job.contextualStrings
            try await analyzer.setContext(context)
        }
        let file = try AVAudioFile(forReading: URL(fileURLWithPath: job.audioPath))
        async let finalText = collectFinalText(from: transcriber)
        try await analyzer.start(inputAudioFile: file, finishAfterFile: true)
        let raw = try await finalText
        let corrected = DSpeechLexiconCorrector(terms: job.correctionStrings ?? job.contextualStrings).correct(raw)
        return Result(id: job.id, status: "ok", rawText: raw, correctedText: corrected,
                      reason: nil, elapsedSeconds: Date().timeIntervalSince(started))
    } catch {
        await analyzer.cancelAndFinishNow()
        return Result(id: job.id, status: "failed", rawText: nil, correctedText: nil,
                      reason: String(describing: error), elapsedSeconds: Date().timeIntervalSince(started))
    }
}

@main
private enum Main {
    static func main() async {
        guard CommandLine.arguments.count == 3 else {
            fputs("Usage: voice-audio-asr jobs.json results.jsonl\n", stderr)
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
                let result = await recognize(job)
                var data = try encoder.encode(result)
                data.append(0x0A)
                try handle.write(contentsOf: data)
                print("\(index + 1)/\(jobs.count) \(job.id): \(result.status)")
            }
        } catch {
            fputs("Audio recognition failed: \(error)\n", stderr)
            exit(1)
        }
    }
}
