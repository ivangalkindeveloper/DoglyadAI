public struct DNeuralDictationNumberLocalization: Decodable, Sendable {
    public let ones: [String]
    public let tens: [String]
    public let hundred: String
    public let digits: [String: String]
}
