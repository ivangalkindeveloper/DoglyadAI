import Foundation

/// Runs the production corrector against frozen device transcripts, without
/// decoding audio, calling a model, or replacing the recorded form results.
@main
enum LexiconReplay {
    private struct LocalizationCatalog: Decodable {
        let speech: DSpeechLexiconLocalization
    }

    static func main() throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 4 else {
            throw NSError(domain: "LexiconReplay", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Usage: LexiconReplay <device-results.json> <config-directory> <output.json>",
            ])
        }
        let source = URL(fileURLWithPath: arguments[1])
        let config = URL(fileURLWithPath: arguments[2])
        let data = try JSONSerialization.jsonObject(with: Data(contentsOf: source)) as! [String: Any]
        let rows = data["results"] as! [[String: Any]]
        var results: [[String: Any]] = []
        for row in rows where row["status"] as? String == "ok" {
            let locale = row["locale"] as! String
            let typeId = row["examinationTypeId"] as! String
            let catalogURL = config.appendingPathComponent(locale).appendingPathComponent("l10n_ultrasound_examination_contextual_strings.json")
            let catalog = try JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as! [String: [String]]
            guard let terms = catalog[typeId] else {
                throw NSError(domain: "LexiconReplay", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing examination vocabulary: \(typeId)"])
            }
            let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            let localizationURL = root.appendingPathComponent("ios/Doglyad/Resources/Localization")
                .appendingPathComponent("\(locale).lproj/VoiceParsing.json")
            let localization = try JSONDecoder().decode(LocalizationCatalog.self, from: Data(contentsOf: localizationURL))
            let corrector = DSpeechLexiconCorrector(terms: terms, localization: localization.speech)
            let raw = row["rawText"] as! String
            let ideal = row["inputText"] as! String
            results.append([
                "id": row["id"]!, "locale": locale, "examinationTypeId": typeId,
                "rawText": raw, "recordedCorrectedText": row["correctedText"]!,
                "replayedCorrectedText": corrector.correct(raw),
                "idealInputText": ideal, "replayedIdealText": corrector.correct(ideal),
            ])
        }
        let output: [String: Any] = [
            "scope": "Lexicon only; no ASR or model calls; recorded proposals unchanged",
            "fixtureSha256": data["fixtureSha256"]!, "results": results,
        ]
        try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys])
            .write(to: URL(fileURLWithPath: arguments[3]))
    }
}
