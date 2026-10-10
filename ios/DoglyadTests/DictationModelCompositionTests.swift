@testable import DoglyadNeuralModel
import Foundation
import Testing

@MainActor
struct DictationModelCompositionTests {
    @Test(
        "Available Foundation Models wins and performs one generation",
    )
    func foundationPrecedence() async throws {
        let generator = GeneratorStub()
        let transport = try TransportStub()
        let provider = ProviderStub(
            model: DNeuralUltrasoundModelFoundationModels(
                generator: generator,
            ),
        )
        let factory = DNeuralUltrasoundModelFactory(
            foundationProvider: provider,
            serverModel: DNeuralUltrasoundModelServer(
                transport: transport,
            ),
        )
        let result = try await factory.model().parseProposals(
            request: request(),
        )
        #expect(
            result.source == .localModel,
        )
        #expect(
            result.proposals.map(
                \.id,
            ) == [.patientName, .patientWeightKG],
        )
        #expect(
            generator.calls == 1,
        )
        #expect(
            transport.calls == 0,
        )
        #expect(
            generator.request?.examinationTypeTitle == "Брюшная полость",
        )
    }

    @Test(
        "Unavailable Foundation Models uses the same public model interface for the server",
    )
    func serverSelection() async throws {
        let generator = GeneratorStub()
        let transport = try TransportStub()
        let provider = ProviderStub(
            model: DNeuralUltrasoundModelFoundationModels(
                generator: generator,
            ),
        )
        provider.isAvailable = false
        let factory = DNeuralUltrasoundModelFactory(
            foundationProvider: provider,
            serverModel: DNeuralUltrasoundModelServer(
                transport: transport,
            ),
        )
        let result = try await factory.model().parseProposals(
            request: request(),
        )
        #expect(
            result.source == .serverModel,
        )
        #expect(
            result.proposals.map(
                \.id,
            ) == [.patientName, .patientWeightKG],
        )
        #expect(
            result.proposals.last?.value == .number(
                68,
            ),
        )
        #expect(
            generator.calls == 0,
        )
        #expect(
            provider.creations == 0,
        )
        #expect(
            transport.calls == 1,
        )
        #expect(
            transport.locale == Locale(
                identifier: "ru",
            ),
        )
        #expect(
            transport.typeID == "abdominalCavity",
        )
        #expect(
            transport.text == request().text,
        )
    }

    @Test(
        "Cached model selection responds to capability changes and unload",
    )
    func capabilityChanges() throws {
        let provider = ProviderStub(
            model: DNeuralUltrasoundModelFoundationModels(
                generator: GeneratorStub(),
            ),
        )
        let server = try DNeuralUltrasoundModelServer(
            transport: TransportStub(),
        )
        let factory = DNeuralUltrasoundModelFactory(
            foundationProvider: provider,
            serverModel: server,
        )
        let first = try factory.model() as AnyObject
        let second = try factory.model() as AnyObject
        #expect(
            first === second,
        )
        #expect(
            provider.creations == 1,
        )
        provider.isAvailable = false
        #expect(
            try factory.model() as AnyObject === server,
        )
        provider.isAvailable = true
        _ = try factory.model()
        #expect(
            provider.creations == 2,
        )
        factory.unload()
        _ = try factory.model()
        #expect(
            provider.creations == 3,
        )
    }

    @Test(
        "Local preparation is delegated; server preparation sends no request",
    )
    func preparation() throws {
        let generator = GeneratorStub()
        DNeuralUltrasoundModelFoundationModels(
            generator: generator,
        ).prewarm()
        #expect(
            generator.prewarms == 1,
        )
        let transport = try TransportStub()
        DNeuralUltrasoundModelServer(
            transport: transport,
        ).prewarm()
        #expect(
            transport.calls == 0,
        )
    }

    @Test(
        "A local error preserves explicit fields without invoking the server",
    )
    func localFailureWithExplicitFields() async throws {
        let generator = GeneratorStub()
        generator.error = TestFailure.failed
        let transport = try TransportStub()
        let provider = ProviderStub(
            model: DNeuralUltrasoundModelFoundationModels(
                generator: generator,
            ),
        )
        let factory = DNeuralUltrasoundModelFactory(
            foundationProvider: provider,
            serverModel: DNeuralUltrasoundModelServer(
                transport: transport,
            ),
        )
        let result = try await factory.model().parseProposals(
            request: request(),
        )
        #expect(
            result.proposals.count == 2,
        )
        #expect(
            result.proposals.last?.value == .number(
                68,
            ),
        )
        #expect(
            generator.calls == 1,
        )
        #expect(
            transport.calls == 0,
        )
    }

    @Test(
        "A local error without explicit fields reaches the caller",
    )
    func localFailureWithoutFields() async {
        let generator = GeneratorStub()
        generator.error = TestFailure.failed
        let model = DNeuralUltrasoundModelFoundationModels(
            generator: generator,
        )
        await #expect(
            throws: TestFailure.failed,
        ) {
            try await model.parseProposals(
                request: request(
                    text: "...",
                ),
            )
        }
        #expect(
            generator.calls == 1,
        )
    }

    @Test(
        "Cancellation never returns explicit fields or starts a server request",
    )
    func localCancellation() async throws {
        let generator = GeneratorStub()
        generator.error = CancellationError()
        let transport = try TransportStub()
        let provider = ProviderStub(
            model: DNeuralUltrasoundModelFoundationModels(
                generator: generator,
            ),
        )
        let factory = DNeuralUltrasoundModelFactory(
            foundationProvider: provider,
            serverModel: DNeuralUltrasoundModelServer(
                transport: transport,
            ),
        )
        await #expect(
            throws: CancellationError.self,
        ) {
            try await factory.model().parseProposals(
                request: request(),
            )
        }
        #expect(
            generator.calls == 1,
        )
        #expect(
            transport.calls == 0,
        )
    }

    @Test(
        "Server failures are not replaced with explicit-only results",
    )
    func serverFailure() async throws {
        let transport = try TransportStub()
        transport.error = TestFailure.failed
        let model = DNeuralUltrasoundModelServer(
            transport: transport,
        )
        await #expect(
            throws: TestFailure.failed,
        ) {
            try await model.parseProposals(
                request: request(),
            )
        }
        #expect(
            transport.calls == 1,
        )
    }

    @Test(
        "Cancellation while an implementation returns discards its result",
    )
    func cancellationAfterResponse() async throws {
        let generator = GeneratorStub()
        generator.cancelBeforeReturning = true
        let local = DNeuralUltrasoundModelFoundationModels(
            generator: generator,
        )
        let localTask = Task { try await local.parseProposals(
            request: request(),
        ) }
        await #expect(
            throws: CancellationError.self,
        ) { try await localTask.value }
        let transport = try TransportStub()
        transport.cancelBeforeReturning = true
        let server = DNeuralUltrasoundModelServer(
            transport: transport,
        )
        let serverTask = Task { try await server.parseProposals(
            request: request(),
        ) }
        await #expect(
            throws: CancellationError.self,
        ) { try await serverTask.value }
        #expect(
            generator.calls == 1,
        )
        #expect(
            transport.calls == 1,
        )
    }

    @Test(
        "Already cancelled dictation performs no generation",
    )
    func cancellationBeforeGeneration() async {
        let generator = GeneratorStub()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await DNeuralUltrasoundModelFoundationModels(
                generator: generator,
            ).parseProposals(
                request: request(),
            )
        }
        await #expect(
            throws: CancellationError.self,
        ) { try await task.value }
        #expect(
            generator.calls == 0,
        )
    }

    @Test(
        "Server metadata and literal unmatched findings survive shared processing",
    )
    func serverMetadata() async throws {
        let transport = try TransportStub(
            json: #"{"proposals":[],"rejectedFieldIds":["patient_date_of_birth"],"unmappedFindings":["Нужно уточнить анамнез."]}"#,
        )
        let result = try await DNeuralUltrasoundModelServer(
            transport: transport,
        ).parseProposals(
            request: request(
                text: "Вес: 68 кг. Описание исследования: Печень без особенностей. Нужно уточнить анамнез.",
            ),
        )
        #expect(
            result.source == .serverModel,
        )
        #expect(
            result.proposals.first?.value == .number(
                68,
            ),
        )
        #expect(
            result.rejectedFieldIds == [.patientDateOfBirth],
        )
        #expect(
            result.unmappedFindings == ["Нужно уточнить анамнез."],
        )
        #expect(
            result.fieldSources[
                .patientWeightKG,
            ] != nil,
        )
    }

    @Test(
        "A factory construction failure does not issue another generation",
    )
    func constructionFailure() async throws {
        let provider = ProviderStub(
            model: DNeuralUltrasoundModelFoundationModels(
                generator: GeneratorStub(),
            ),
        )
        provider.error = TestFailure.failed
        let transport = try TransportStub()
        let factory = DNeuralUltrasoundModelFactory(
            foundationProvider: provider,
            serverModel: DNeuralUltrasoundModelServer(
                transport: transport,
            ),
        )
        #expect(
            throws: TestFailure.failed,
        ) { try factory.model() }
        #expect(
            provider.creations == 1,
        )
        #expect(
            transport.calls == 0,
        )
    }

    @Test(
        "Missing local prompt does not prevent creation of a server parser",
    )
    func missingLocalPrompt() throws {
        let transport = try TransportStub()
        let factory = DNeuralUltrasoundModelFactory(
            locale: Locale(
                identifier: "en",
            ),
            proposalPrompt: " ",
            parameters: DNeuralGenerationParameters(
                temperature: 0,
                maxTokens: 512,
                maxContextTokens: 4096,
            ),
            serverTransport: transport,
        )
        #expect(
            try factory.model() is DNeuralUltrasoundModelServer,
        )
    }

    private func request(
        text: String = "Пациент: Анна Петрова. Вес 68 кг.",
    ) -> DNeuralUltrasoundDictationParseRequest {
        let locale = Locale(
            identifier: "ru",
        )
        return DNeuralUltrasoundDictationParseRequest(
            text: text,
            examinationTypeId: "abdominalCavity",
            examinationTypeTitle: "Брюшная полость",
            locale: locale,
            allowedFields: DNeuralUltrasoundVoiceFieldId.allCases,
            localization: VoiceLocalizationTestSupport.dictation(
                locale: locale,
            ),
        )
    }
}

private enum TestFailure: Error, Equatable { case failed }

@MainActor
private final class ProviderStub: DNeuralUltrasoundFoundationModelProviderProtocol {
    var isAvailable = true
    var error: (any Error)?
    private(set) var creations = 0
    let model: any DNeuralUltrasoundModelProtocol

    init(
        model: any DNeuralUltrasoundModelProtocol,
    ) { self.model = model }

    func makeModel() throws -> any DNeuralUltrasoundModelProtocol {
        creations += 1
        if let error { throw error }
        return model
    }
}

private final class GeneratorStub: DNeuralUltrasoundProposalGeneratorProtocol {
    var error: (any Error)?
    var cancelBeforeReturning = false
    private(set) var prewarms = 0
    private(set) var calls = 0
    private(set) var request: DNeuralUltrasoundDictationParseRequest?

    func prewarm() { prewarms += 1 }

    func generateProposals(
        request: DNeuralUltrasoundDictationParseRequest,
    ) async throws -> DNeuralUltrasoundProposalGenerationResponse {
        calls += 1
        self.request = request
        if let error { throw error }
        if cancelBeforeReturning { withUnsafeCurrentTask { $0?.cancel() } }
        return DNeuralUltrasoundProposalGenerationResponse(
            proposals: [DNeuralUltrasoundProposalGenerationItem(
                fieldId: .patientWeightKG,
                value: "68",
                sourceQuote: "Вес 68 кг",
                accuracy: .full,
            )],
            unmappedFindings: [],
        )
    }
}

private final class TransportStub: DNeuralUltrasoundServerTransportProtocol {
    private let response: DNeuralUltrasoundVoiceFormParseResponseDTO
    var error: (any Error)?
    var cancelBeforeReturning = false
    private(set) var calls = 0
    private(set) var locale: Locale?
    private(set) var typeID: String?
    private(set) var text: String?

    init(
        json: String = #"{"proposals":[{"field_id":"patient_weight_kg","value":68,"evidence":"Вес 68 кг","accuracy":"full"}],"rejectedFieldIds":[],"unmappedFindings":[]}"#,
    ) throws {
        response = try JSONDecoder().decode(
            DNeuralUltrasoundVoiceFormParseResponseDTO.self,
            from: Data(
                json.utf8,
            ),
        )
    }

    func parseDictation(
        locale: Locale,
        examinationTypeId: String,
        transcript: String,
    ) async throws -> DNeuralUltrasoundVoiceFormParseResponseDTO {
        calls += 1
        self.locale = locale
        typeID = examinationTypeId
        text = transcript
        if let error { throw error }
        if cancelBeforeReturning { withUnsafeCurrentTask { $0?.cancel() } }
        return response
    }
}
