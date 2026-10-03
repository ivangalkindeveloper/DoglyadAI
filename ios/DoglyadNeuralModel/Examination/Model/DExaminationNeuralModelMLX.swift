import Foundation
internal import MLX
internal import MLXGuidedGeneration
internal import MLXLLM
internal import MLXLMCommon
internal import Tokenizers

public final class DExaminationNeuralModelMLX: DExaminationNeuralModelProtocol {
    /// The arrays are derived once from an immutable tokenizer and only read
    /// while adding logit bias during generation.
    private final class TokenizerBias: @unchecked Sendable {
        let closing: MLXArray
        let whitespace: MLXArray
        let whitespaceTokenIDs: Set<Int>

        init(closing: MLXArray, whitespace: MLXArray, whitespaceTokenIDs: Set<Int>) {
            self.closing = closing
            self.whitespace = whitespace
            self.whitespaceTokenIDs = whitespaceTokenIDs
        }
    }

    /// The locale does not affect availability: the language is set by the system
    /// prompt while the weights stay the same. The parameter exists so that all
    /// implementations share one interface.
    public static func isAvailable(
        locale _: Locale,
        parameters: DExaminationGenerationParameters
    ) -> Bool {
        DNeuralDevice.canRunLocally(
            model: defaultModel,
            weightsBytes: resourceBytes,
            maxContextTokens: parameters.maxContextTokens
        )
    }

    private static let resourceName = "mlx-Qwen2.5-1.5B-Instruct-4bit"
    private static let resourceDirectory: URL? = Bundle.main.url(
        forResource: resourceName,
        withExtension: nil
    )

    /// Weight size is measured for real rather than derived from the parameter count:
    /// per-quant scales and zeros do not fit such an estimate, and when the model
    /// changes the actual size updates itself.
    private static let resourceBytes: UInt64 = {
        guard let resourceDirectory else { return 0 }

        return DNeuralResource.directorySize(at: resourceDirectory)
    }()

    /// The mlx-community/Qwen2.5-1.5B-Instruct-4bit architecture, per its config.json.
    private static let defaultModel = DNeuralModelData(
        modelId: "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
        numLayers: 28,
        numKeyValueHeads: 2,
        headDimension: 128
    )
    private let model: MLXLMCommon.ModelContainer
    private let grammarTokenizer: MLXGuidedGeneration.GrammarTokenizer
    private let tokenizerBias: TokenizerBias
    private let systemPrompt: String
    private let proposalPrompt: String?
    private let maxTokens: Int

    public init(
        systemPrompt: String,
        proposalPrompt: String?,
        parameters: DExaminationGenerationParameters
    ) async throws {
        guard let directory = Self.resourceDirectory else {
            throw DExaminationNeuralModelError.resourceNotFound
        }

        // Without a limit the MLX buffer cache grows on top of the weights and on a
        // phone turns into hundreds of megabytes of extra resident memory.
        MLX.Memory.cacheLimit = Self.gpuCacheLimitBytes

        let model = try await MLXLMCommon.loadModelContainer(
            from: directory,
            using: DTransformersTokenizerLoader()
        )
        let generationSetup = try await model.perform { context in
            let grammarVocab = MLXGuidedGeneration.TokenizerVocabExtractor.extractForGrammar(
                from: context.tokenizer
            )
            let grammarTokenizer = try MLXGuidedGeneration.GrammarTokenizer(
                vocab: grammarVocab.vocab,
                vocabType: grammarVocab.vocabType,
                eosTokenId: Int32(context.tokenizer.eosTokenId ?? 0)
            )
            let closingBias = MLXGuidedGeneration.ClosingTokenBias.compute(
                tokenizer: context.tokenizer, eosTokenId: context.tokenizer.eosTokenId
            )
            let whitespace = MLXGuidedGeneration.WhitespaceTokenBias.compute(tokenizer: context.tokenizer)
            return (grammarTokenizer, TokenizerBias(
                closing: closingBias,
                whitespace: whitespace.bias,
                whitespaceTokenIDs: whitespace.tokenIDs
            ))
        }
        let grammarTokenizer = generationSetup.0

        // Compile the schema while the model is loading. XGrammar caches the
        // compilation, so a request only needs a fresh matcher state.
        _ = try await Task.detached(priority: .userInitiated) {
            try MLXGuidedGeneration.GrammarConstraint(
                tokenizer: grammarTokenizer,
                jsonSchema: DExaminationGenerationConfig.responseJSONSchema
            )
        }.value
        if proposalPrompt != nil {
            _ = try await Task.detached(priority: .userInitiated) {
                try MLXGuidedGeneration.GrammarConstraint(
                    tokenizer: grammarTokenizer,
                    jsonSchema: DExaminationProposalGenerationConfig.responseJSONSchema
                )
            }.value
        }

        self.model = model
        self.grammarTokenizer = grammarTokenizer
        tokenizerBias = generationSetup.1
        self.systemPrompt = systemPrompt
        self.proposalPrompt = proposalPrompt
        maxTokens = parameters.maxTokens
    }

    private static let gpuCacheLimitBytes = 32 * 1024 * 1024

    deinit {
        // The weights are freed together with ModelContext, but the MLX buffer cache
        // outlives the model, so it is dropped explicitly.
        MLX.Memory.clearCache()
    }

    /// Weight loading, vocabulary preparation, and schema compilation happen when
    /// the factory creates this instance, so there is no deferred work left here.
    public func prewarm() {}

    public func parseSpeech(
        speech: String
    ) async throws -> DExaminationNeuralModelResponse {
        let data = try await generateResponse(
            systemPrompt: systemPrompt,
            userPrompt: DExaminationGenerationConfig.userPrompt(for: speech),
            schema: DExaminationGenerationConfig.responseJSONSchema
        )
        return try DExaminationGenerationConfig.jsonDecoder.decode(
            DExaminationNeuralModelResponse.self,
            from: data
        )
    }

    public func parseProposals(request: DictationParseRequest) async throws -> DictationProposal {
        guard let proposalPrompt else { throw DExaminationNeuralModelError.proposalPromptUnavailable }
        let data = try await generateResponse(
            systemPrompt: proposalPrompt,
            userPrompt: DExaminationProposalGenerationConfig.userPrompt(for: request),
            schema: DExaminationProposalGenerationConfig.responseJSONSchema
        )
        let generated = try JSONDecoder().decode(DExaminationProposalGenerationResponse.self, from: data)
        return try DictationProposal(generated: generated, request: request)
    }

    private func generateResponse(
        systemPrompt: String,
        userPrompt: String,
        schema: String
    ) async throws -> Data {
        let model = model
        let grammarTokenizer = grammarTokenizer
        let tokenizerBias = tokenizerBias
        let maxTokens = maxTokens
        let generationTask = Task.detached(priority: .userInitiated) {
            try await model.perform { context in
                let constraint = try MLXGuidedGeneration.GrammarConstraint(
                    tokenizer: grammarTokenizer,
                    jsonSchema: schema,
                    fastForward: true,
                    hostTokenizer: context.tokenizer
                )
                let input = try await context.processor.prepare(
                    input: MLXLMCommon.UserInput(
                        chat: [
                            .system(systemPrompt),
                            .user(userPrompt),
                        ]
                    )
                )
                var response = ""
                let structuralReserve = MLXGuidedGeneration.CompletionReserve.estimate(
                    schemaJSON: schema, tokenizer: context.tokenizer
                )
                try MLXGuidedGeneration.GuidedGenerationLoop.run(
                    input: input,
                    context: context,
                    constraint: constraint,
                    maxTokens: maxTokens,
                    vocabSize: grammarTokenizer.vocabSize,
                    completionReserve: max(structuralReserve * 3, maxTokens / 4),
                    hardReserve: structuralReserve * 8,
                    closingBias: tokenizerBias.closing,
                    whitespaceBias: tokenizerBias.whitespace,
                    whitespaceTokenIDs: tokenizerBias.whitespaceTokenIDs
                ) { chunk in
                    response += chunk
                    return true
                }
                return response
            }
        }
        let response = try await withTaskCancellationHandler {
            try await generationTask.value
        } onCancel: {
            generationTask.cancel()
        }
        return Data(response.utf8)
    }
}

private struct DTransformersTokenizerLoader: MLXLMCommon.TokenizerLoader {
    func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        let upstream = try await Tokenizers.AutoTokenizer.from(modelFolder: directory)
        return DTokenizerBridge(upstream)
    }
}

private struct DTokenizerBridge: MLXLMCommon.Tokenizer {
    private let upstream: any Tokenizers.Tokenizer

    init(_ upstream: any Tokenizers.Tokenizer) {
        self.upstream = upstream
    }

    func encode(text: String, addSpecialTokens: Bool) -> [Int] {
        upstream.encode(text: text, addSpecialTokens: addSpecialTokens)
    }

    func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String {
        upstream.decode(tokens: tokenIds, skipSpecialTokens: skipSpecialTokens)
    }

    func convertTokenToId(_ token: String) -> Int? {
        upstream.convertTokenToId(token)
    }

    func convertIdToToken(_ id: Int) -> String? {
        upstream.convertIdToToken(id)
    }

    var bosToken: String? { upstream.bosToken }
    var eosToken: String? { upstream.eosToken }
    var unknownToken: String? { upstream.unknownToken }

    func applyChatTemplate(
        messages: [[String: any Sendable]],
        tools: [[String: any Sendable]]?,
        additionalContext: [String: any Sendable]?
    ) throws -> [Int] {
        do {
            return try upstream.applyChatTemplate(
                messages: messages,
                tools: tools,
                additionalContext: additionalContext
            )
        } catch Tokenizers.TokenizerError.missingChatTemplate {
            throw MLXLMCommon.TokenizerError.missingChatTemplate
        }
    }
}
