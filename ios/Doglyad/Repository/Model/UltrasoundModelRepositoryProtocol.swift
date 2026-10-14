protocol UltrasoundModelRepositoryProtocol: AnyObject {
    // MARK: Model -

    func getSelectedModelId() async throws -> String?

    func setSelectedModelId(
        id: String,
    ) async throws

    func getIsMarkdown() async throws -> Bool

    func setIsMarkdown(
        _ isMarkdown: Bool,
    ) async throws

    func getTemperature() async throws -> Double?

    func setTemperature(
        _ value: Double?,
    ) async throws

    func getMaxTokens() async throws -> Int?

    func setMaxTokens(
        _ value: Int?,
    ) async throws
}
