public struct DNeuralDictationShortUnitLocalization: Decodable, Sendable {
    public let millimeter: String
    public let velocity: String
    public let milliliter: String

    init(
        millimeter: String,
        velocity: String,
        milliliter: String,
    ) {
        self.millimeter = millimeter
        self.velocity = velocity
        self.milliliter = milliliter
    }
}
