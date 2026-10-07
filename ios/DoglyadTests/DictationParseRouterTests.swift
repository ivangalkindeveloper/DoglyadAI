@testable import DoglyadNeuralModel
import Foundation
import Testing

@MainActor
struct DictationParseRouterTests {
    private let request = DictationParseRequest(
        text: "Пациент: Анна Петрова. Вес 68 кг.",
        examinationTypeId: "abdominalCavity",
        locale: Locale(identifier: "ru_RU"),
        allowedFields: VoiceFieldId.allCases
    )

    @Test("Available Foundation Models takes precedence over the server")
    func availableFoundationModels() async throws {
        var localCalls = 0
        var serverCalls = 0
        let expected = DictationProposal(
            source: .localModel, proposals: [], unmappedFindings: [], rejectedFieldIds: []
        )
        let result = try await DictationParseRouter.parse(
            request: request,
            isFoundationModelsAvailable: true,
            parseFoundationModels: {
                localCalls += 1
                return expected
            },
            parseServer: {
                serverCalls += 1
                return try self.serverResponse()
            }
        )
        #expect(result.source == .localModel)
        #expect(localCalls == 1)
        #expect(serverCalls == 0)
    }

    @Test("Unavailable Foundation Models routes partial dictation to the server")
    func unavailableFoundationModels() async throws {
        var localCalls = 0
        var serverCalls = 0
        let result = try await DictationParseRouter.parse(
            request: request,
            isFoundationModelsAvailable: false,
            parseFoundationModels: {
                localCalls += 1
                throw DExaminationNeuralModelError.unavailable
            },
            parseServer: {
                serverCalls += 1
                return try self.serverResponse()
            }
        )
        #expect(localCalls == 0)
        #expect(serverCalls == 1)
        #expect(result.source == .serverModel)
        #expect(result.proposals.map(\.id) == [.patientWeightKG])
        #expect(result.proposals.first?.value == .number(68))
        #expect(result.rejectedFieldIds.isEmpty)
    }

    @Test("A local failure or cancellation does not start a second generation")
    func localFailure() async {
        var serverCalls = 0
        do {
            _ = try await DictationParseRouter.parse(
                request: request,
                isFoundationModelsAvailable: true,
                parseFoundationModels: { throw CancellationError() },
                parseServer: {
                    serverCalls += 1
                    return try self.serverResponse()
                }
            )
            Issue.record("Expected the local cancellation")
        } catch is CancellationError {
            #expect(serverCalls == 0)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    private func serverResponse() throws -> USVoiceFormParseResponseDTO {
        let data = Data(#"{"proposals":[{"field_id":"patient_weight_kg","value":68,"evidence":"Вес 68 кг","accuracy":"full"}],"rejectedFieldIds":[],"unmappedFindings":[]}"#.utf8)
        return try JSONDecoder().decode(USVoiceFormParseResponseDTO.self, from: data)
    }
}
