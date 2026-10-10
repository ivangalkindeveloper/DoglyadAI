/// Isolates system capability checks and construction from the factory lifecycle.
@MainActor
protocol DNeuralUltrasoundFoundationModelProviderProtocol {
    var isAvailable: Bool { get }
    func makeModel() throws -> any DNeuralUltrasoundModelProtocol
}
