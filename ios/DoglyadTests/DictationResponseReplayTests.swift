@testable import DoglyadNeuralModel
import Foundation
import XCTest

final class DictationResponseReplayTests: XCTestCase {
    @MainActor
    func testStoredResponsesPreserveBothPipelines() async throws {
        let url = try XCTUnwrap(
            Bundle(
                for: Self.self,
            ).url(
                forResource: "response-replay",
                withExtension: "json",
            ),
        )
        let cases = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: Data(
                    contentsOf: url,
                ),
            ) as? [[String: Any]],
        )
        XCTAssertEqual(
            cases.count,
            372,
        )
        for index in cases.indices {
            let item = cases[
                index,
            ]
            let locale = try Locale(
                identifier: XCTUnwrap(
                    item[
                        "locale",
                    ] as? String,
                ),
            )
            let request = try DNeuralUltrasoundDictationParseRequest(
                text: XCTUnwrap(
                    item[
                        "text",
                    ] as? String,
                ),
                examinationTypeId: XCTUnwrap(
                    item[
                        "examinationTypeId",
                    ] as? String,
                ),
                examinationTypeTitle: XCTUnwrap(
                    item[
                        "examinationTypeTitle",
                    ] as? String,
                ),
                locale: locale,
                allowedFields: DNeuralUltrasoundVoiceFieldId.allCases,
                localization: VoiceLocalizationTestSupport.dictation(
                    locale: locale,
                ),
            )
            let response = try JSONDecoder().decode(
                DNeuralUltrasoundVoiceFormParseResponseDTO.self,
                from: JSONSerialization.data(
                    withJSONObject: XCTUnwrap(
                        item[
                            "response",
                        ],
                    ),
                ),
            )
            let local = try DNeuralUltrasoundProposalProcessor(
                request: request,
            ).process(
                generated: DNeuralUltrasoundProposalGenerationResponse(
                    serverResponse: response,
                ),
                source: .localModel,
            )
            let server = try await DNeuralUltrasoundModelServer(
                transport: ReplayTransport(
                    response: response,
                ),
            ).parseProposals(
                request: request,
            )
            XCTAssertEqual(
                signature(
                    local,
                ) as NSDictionary,
                try XCTUnwrap(
                    item[
                        "expectedLocal",
                    ] as? NSDictionary,
                ),
                "Local processing changed: \(item["id"] ?? index)",
            )
            XCTAssertEqual(
                signature(
                    server,
                ) as NSDictionary,
                try XCTUnwrap(
                    item[
                        "expectedServer",
                    ] as? NSDictionary,
                ),
                "Server processing changed: \(item["id"] ?? index)",
            )
        }
    }

    private func signature(
        _ result: DNeuralUltrasoundDictationProposal,
    ) -> [String: Any] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return [
            "source": String(
                describing: result.source,
            ),
            "proposals": result.proposals.map { proposal in
                let value: Any = switch proposal.value {
                case let .text(
                    text,
                ): text
                case let .number(
                    number,
                ): number
                case let .gender(
                    gender,
                ): gender.rawValue
                case let .date(
                    date,
                ): formatter.string(
                        from: date,
                    )
                }
                return [
                    "field": proposal.id.wireValue,
                    "value": value,
                    "evidence": proposal.sourceQuote,
                    "accuracy": proposal.accuracy.rawValue,
                    "warnings": proposal.warnings.map(
                        \.rawValue,
                    ),
                ] as [String: Any]
            },
            "rejected": result.rejectedFieldIds.map(
                \.wireValue,
            ),
            "unmapped": result.unmappedFindings,
            "fieldSources": Dictionary(
                uniqueKeysWithValues: result.fieldSources.map { ($0.key.wireValue, String(
                    describing: $0.value,
                )) },
            ),
        ]
    }
}

private struct ReplayTransport: DNeuralUltrasoundServerTransportProtocol {
    let response: DNeuralUltrasoundVoiceFormParseResponseDTO

    func parseDictation(
        locale _: Locale,
        examinationTypeId _: String,
        transcript _: String,
    ) async throws -> DNeuralUltrasoundVoiceFormParseResponseDTO {
        response
    }
}
