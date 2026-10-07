import Foundation

public enum DictationParseRouter {
    /// Availability is checked for each dictation. An available Foundation Models
    /// parser is always used; its errors are returned without a second generation.
    @MainActor
    public static func parse(
        request: DictationParseRequest,
        isFoundationModelsAvailable: Bool,
        parseFoundationModels: () async throws -> DictationProposal,
        parseServer: () async throws -> USVoiceFormParseResponseDTO
    ) async throws -> DictationProposal {
        try Task.checkCancellation()
        if isFoundationModelsAvailable {
            return try await parseFoundationModels()
        }
        let response = try await parseServer()
        try Task.checkCancellation()
        return try DictationProposal(serverResponse: response, request: request)
    }
}
