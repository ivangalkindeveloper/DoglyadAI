import Foundation
import MLX
import MLXGuidedGeneration
import MLXLLM
import MLXLMCommon
import Tokenizers

private struct Request: Decodable {
    let id: String
    let systemPrompt: String
    let userPrompt: String
    let schema: String
    let maxTokens: Int
}

private struct Response: Encodable {
    let id: String
    let output: String?
    let error: String?
}

@main
private enum VoiceGuidedHarness {
    static func main() async throws {
        guard CommandLine.arguments.count == 2 else {
            throw NSError(domain: "VoiceGuidedHarness", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Usage: voice-guided <local-model-directory>"
            ])
        }
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let model = try await MLXLMCommon.loadModelContainer(from: directory, using: LocalTokenizerLoader())
        let grammarTokenizer = try await model.perform { context in
            let grammarVocab = TokenizerVocabExtractor.extractForGrammar(from: context.tokenizer)
            return try GrammarTokenizer(
                vocab: grammarVocab.vocab,
                vocabType: grammarVocab.vocabType,
                eosTokenId: Int32(context.tokenizer.eosTokenId ?? 0)
            )
        }
        while let line = readLine() {
            guard let data = line.data(using: .utf8) else { continue }
            let request = try JSONDecoder().decode(Request.self, from: data)
            let response: Response
            do {
                let output = try await model.perform { context in
                    let constraint = try GrammarConstraint(
                        tokenizer: grammarTokenizer,
                        jsonSchema: request.schema,
                        fastForward: true,
                        hostTokenizer: context.tokenizer
                    )
                    let input = try await context.processor.prepare(input: UserInput(chat: [
                        .system(request.systemPrompt),
                        .user(request.userPrompt),
                    ]))
                    var result = ""
                    try GuidedGenerationLoop.run(
                        input: input,
                        context: context,
                        constraint: constraint,
                        maxTokens: request.maxTokens,
                        vocabSize: grammarTokenizer.vocabSize
                    ) { chunk in
                        result += chunk
                        return true
                    }
                    return result
                }
                response = Response(id: request.id, output: output, error: nil)
            } catch {
                response = Response(id: request.id, output: nil, error: String(describing: error))
            }
            let output = try JSONEncoder().encode(response)
            print("VOICE_GUIDED:\(String(decoding: output, as: UTF8.self))")
            fflush(stdout)
        }
    }
}

private struct LocalTokenizerLoader: MLXLMCommon.TokenizerLoader {
    func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        TokenizerBridge(try await AutoTokenizer.from(modelFolder: directory))
    }
}

private struct TokenizerBridge: MLXLMCommon.Tokenizer {
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

    func convertTokenToId(_ token: String) -> Int? { upstream.convertTokenToId(token) }
    func convertIdToToken(_ id: Int) -> String? { upstream.convertIdToToken(id) }
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
                messages: messages, tools: tools, additionalContext: additionalContext
            )
        } catch Tokenizers.TokenizerError.missingChatTemplate {
            throw MLXLMCommon.TokenizerError.missingChatTemplate
        }
    }
}
