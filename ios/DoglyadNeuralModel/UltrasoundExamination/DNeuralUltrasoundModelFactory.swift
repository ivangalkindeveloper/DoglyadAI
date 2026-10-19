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

    public var isFoundationModelsAvailable: Bool { foundationProvider.isAvailable }

    deinit {
        if let memoryWarningObserver { NotificationCenter.default.removeObserver(
            memoryWarningObserver,
        ) }
    }

    public func model(
        isFoundationModels: Bool,
    ) throws -> any DNeuralUltrasoundModelProtocol {
        guard isFoundationModels else {
            foundationModel = nil
            return serverModel
        }
        guard foundationProvider.isAvailable else {
            foundationModel = nil
            throw DNeuralModelError.unavailable
        }
        if let foundationModel { return foundationModel }
        let model = try foundationProvider.makeModel()
        foundationModel = model
        return model
    }

    public func prewarm(
        isFoundationModels: Bool,
    ) {
        Task { [weak self] in
            guard let model = try? self?.model(
                isFoundationModels: isFoundationModels,
            ) else { return }
            model.prewarm()
        }
    }

    public func unload() {
        foundationModel = nil
    }
}
