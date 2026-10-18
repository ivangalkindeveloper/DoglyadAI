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
                metadataSignature(
                    signature(
                        local,
                    ),
                ),
                try metadataSignature(
                    XCTUnwrap(
                        item[
                            "expectedLocal",
                        ] as? [String: Any],
                    ),
                ),
                "Local processing changed: \(item["id"] ?? index)",
            )
            XCTAssertEqual(
                metadataSignature(
                    signature(
                        server,
                    ),
                ),
                try metadataSignature(
                    XCTUnwrap(
                        item[
                            "expectedServer",
                        ] as? [String: Any],
                    ),
                ),
                "Server processing changed: \(item["id"] ?? index)",
            )
            for result in [local, server] {
                assertClinicalModelValues(
                    result,
                    response: response,
                    caseId: String(
                        describing: item[
                            "id",
                        ] ?? index,
                    ),
                )
            }
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
            "fieldSources": Dictionary(
                uniqueKeysWithValues: result.fieldSources.map { ($0.key.wireValue, String(
                    describing: $0.value,
                )) },
            ),
        ]
    }

    // Keep historical metadata expectations. Clinical fields now preserve the
    // model response instead of the old source-text replacement; check that
    // contract directly without rewriting recorded evaluation outputs.
    private func metadataSignature(
        _ recorded: [String: Any],
    ) -> NSDictionary {
        var result = recorded
        result.removeValue(
            forKey: "rejected",
        )
        result.removeValue(
            forKey: "unmapped",
        )
        let clinicalFields = Set(
            ["patient_complaints", "examination_description"],
        )
        result[
            "proposals",
        ] = (recorded[
            "proposals",
        ] as? [[String: Any]])?.filter {
            !clinicalFields.contains(
                $0[
                    "field",
                ] as? String ?? "",
            )
        }
        result[
            "fieldSources",
        ] = (recorded[
            "fieldSources",
        ] as? [String: String])?.filter {
            !clinicalFields.contains(
                $0.key,
            )
        }
        return result as NSDictionary
    }

    private func assertClinicalModelValues(
        _ result: DNeuralUltrasoundDictationProposal,
        response: DNeuralUltrasoundVoiceFormParseResponseDTO,
        caseId: String,
    ) {
        let expected = response.proposals.filter {
            $0.fieldId.isPatientComplaints || $0.fieldId.isExaminationDescription
        }
        let actual = result.proposals.filter {
            $0.id.isPatientComplaints || $0.id.isExaminationDescription
        }
        XCTAssertEqual(
            actual.count,
            expected.count,
            caseId,
        )
        for item in expected {
            guard let proposal = actual.first(
                where: { $0.id == item.fieldId },
            ) else {
                XCTFail(
                    "Missing model clinical field: \(caseId), \(item.fieldId)",
                )
                continue
            }
            XCTAssertEqual(
                proposal.value,
                .text(
                    item.value,
                ),
                caseId,
            )
            XCTAssertEqual(
                proposal.sourceQuote,
                item.sourceQuote,
                caseId,
            )
            XCTAssertEqual(
                result.fieldSources[
                    item.fieldId,
                ],
                result.source,
                caseId,
            )
            if item.value != item.sourceQuote || item.accuracy == .questionable || !proposal.warnings.isEmpty {
                XCTAssertEqual(
                    proposal.accuracy,
                    .questionable,
                    caseId,
                )
            }
        }
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
