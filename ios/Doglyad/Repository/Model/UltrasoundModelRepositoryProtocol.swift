protocol UltrasoundModelRepositoryProtocol: AnyObject {
    // MARK: Model -

    func getSelectedModelId() -> String?

    func setSelectedModelId(
        id: String,
    )

    func getIsMarkdown() -> Bool

    func setIsMarkdown(
        _ value: Bool,
    )

    func getTemperature() -> Double?

    func setTemperature(
        _ value: Double?,
    )

    func getMaxTokens() -> Int?

    func setMaxTokens(
        _ value: Int?,
    )
}
