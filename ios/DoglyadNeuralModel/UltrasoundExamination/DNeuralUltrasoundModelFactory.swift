import Foundation
import UIKit

/// Selects and prepares one parser; extraction and validation belong to that model.
@MainActor
public final class DNeuralUltrasoundModelFactory {
    private let foundationProvider: any DNeuralUltrasoundFoundationModelProviderProtocol
    private let serverModel: any DNeuralUltrasoundModelProtocol
    private var foundationModel: (any DNeuralUltrasoundModelProtocol)?
    private var memoryWarningObserver: (any NSObjectProtocol)?

    public convenience init(
        locale: Locale,
        proposalPrompt: String,
        parameters: DNeuralGenerationParameters,
        serverTransport: any DNeuralUltrasoundServerTransportProtocol,
    ) {
        self.init(
            foundationProvider: DNeuralUltrasoundFoundationModelProvider(
                locale: locale,
                proposalPrompt: proposalPrompt,
                parameters: parameters,
            ),
            serverModel: DNeuralUltrasoundModelServer(
                transport: serverTransport,
            ),
        )
    }

    init(
        foundationProvider: any DNeuralUltrasoundFoundationModelProviderProtocol,
        serverModel: any DNeuralUltrasoundModelProtocol,
    ) {
        self.foundationProvider = foundationProvider
        self.serverModel = serverModel
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main,
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.unload() }
        }
    }

    deinit {
        if let memoryWarningObserver { NotificationCenter.default.removeObserver(
            memoryWarningObserver,
        ) }
    }

    /// Checked on every selection: Foundation Models can become ready or unavailable at runtime.
    public func model() throws -> any DNeuralUltrasoundModelProtocol {
        guard foundationProvider.isAvailable else {
            foundationModel = nil
            return serverModel
        }
        if let foundationModel { return foundationModel }
        let model = try foundationProvider.makeModel()
        foundationModel = model
        return model
    }

    public func prewarm() {
        Task { [weak self] in
            guard let model = try? self?.model() else { return }
            model.prewarm()
        }
    }

    public func unload() {
        foundationModel = nil
    }
}
