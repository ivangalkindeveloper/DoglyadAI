@testable import DoglyadNeuralModel
import Foundation
import UIKit
import XCTest

final class VoiceGuidedReplayTests: XCTestCase {
    @MainActor
    func testGuidedReplay() throws {
        guard ProcessInfo.processInfo.environment["VOICE_GUIDED_REPLAY_RUN"] == "1" else {
            throw XCTSkip("Run through evaluation.voice.replay_guided_ios")
        }
        let bundle = Bundle(for: Self.self)
        let source = try XCTUnwrap(
            bundle.url(forResource: "guided-cases", withExtension: "json", subdirectory: "VoiceFixtures")
                ?? bundle.url(forResource: "guided-cases", withExtension: "json")
        )
        let fixture = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: source)) as? [String: Any])
        let cases = try XCTUnwrap(fixture["cases"] as? [[String: Any]])
        var rows: [[String: Any]] = []
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        for testCase in cases {
            let id = try string(testCase, "id")
            let code = try string(testCase, "locale")
            let locale = Locale(identifier: code == "ru" ? "ru_RU" : "en_US")
            let text = try string(testCase, "inputText")
            let request = try DictationParseRequest(
                text: text,
                examinationTypeId: string(testCase, "examinationTypeId"),
                locale: locale,
                allowedFields: VoiceFieldId.allCases
            )
            let result: [String: Any]
            if let response = testCase["response"] as? String {
                do {
                    let generated = try JSONDecoder().decode(
                        DExaminationProposalGenerationResponse.self, from: Data(response.utf8)
                    )
                    let proposal = try DictationProposal(generated: generated, request: request)
                    var fields: [String: Any] = [:]
                    var warnings: [String: [String]] = [:]
                    var quotes: [String: String] = [:]
                    for item in proposal.proposals {
                        let value: Any
                        switch item.value {
                        case let .text(text): value = text
                        case let .gender(gender): value = gender.rawValue
                        case let .date(date): value = formatter.string(from: date)
                        case let .number(number): value = number
                        }
                        fields[item.id.rawValue] = value
                        warnings[item.id.rawValue] = item.warnings.map(\.rawValue)
                        quotes[item.id.rawValue] = item.sourceQuote
                    }
                    result = [
                        "status": "ok", "fields": fields, "warnings": warnings,
                        "sourceQuotes": quotes,
                        "rejectedFieldIds": proposal.rejectedFieldIds.map(\.rawValue),
                        "unmappedFindings": proposal.unmappedFindings,
                    ]
                } catch {
                    result = ["status": "failed", "reason": String(describing: error)]
                }
            } else {
                result = ["status": "skipped", "reason": "Mac model did not produce a response"]
            }
            rows.append(["id": id, "locale": code, "result": result])
        }

        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        let runID = ProcessInfo.processInfo.environment["VOICE_REPORT_ID"] ?? "manual"
        let report: [String: Any] = [
            "runId": runID,
            "sourceReportSha256": fixture["sourceReportSha256"] ?? NSNull(),
            "corpusSha256": fixture["corpusSha256"] ?? NSNull(),
            "results": rows,
        ]
        let destination = documents.appendingPathComponent("voice-guided-replay-ios-\(runID).json")
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: destination, options: .atomic)
        XCTAssertEqual(rows.count, cases.count)
        print("VOICE_GUIDED_REPLAY_REPORT=\(destination.path)")
    }

    private func string(_ source: [String: Any], _ key: String) throws -> String {
        try XCTUnwrap(source[key] as? String)
    }
}
