public struct DNeuralDictationNumberLocalization: Decodable, Sendable {
    public let ones: [String]
    public let tens: [String]
    public let hundred: String
    public let digits: [String: String]

    init(
        ones: [String],
        tens: [String],
        hundred: String,
        digits: [String: String],
    ) {
        self.ones = ones
        self.tens = tens
        self.hundred = hundred
        self.digits = digits
    }
}
