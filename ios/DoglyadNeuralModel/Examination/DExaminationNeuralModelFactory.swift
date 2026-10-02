import Foundation
import UIKit

/// Creates and holds the local dictation-parsing model, picking its implementation
/// (Foundation Models or MLX) by what the current system supports and by the
/// dictation language.
///
/// The model weighs hundreds of megabytes and coexists with the camera session on
/// the scanning screen, so it is loaded lazily — on the first parse or warm-up
/// rather than at app start — and released when the system asks for memory back.
@MainActor
public final class DExaminationNeuralModelFactory {
    private let locale: Locale
    private let systemPrompt: String
    private let proposalPrompt: String?
    private let parameters: DExaminationGenerationParameters
    private var loadedModel: (any DExaminationNeuralModelProtocol)?
    private var loadingTask: Task<any DExaminationNeuralModelProtocol, any Error>?
    private var memoryWarningObserver: (any NSObjectProtocol)?

    /// Availability does not require loading the model — only memory, system and
    /// language checks — so it can be queried from anywhere, for example while
    /// building a screen.
    public nonisolated var isAvailable: Bool {
        if #available(iOS 26.0, *),
           DExaminationNeuralModelFoundationModels.isAvailable(locale: locale, parameters: parameters)
        {
            return true
        }

        return DExaminationNeuralModelMLX.isAvailable(locale: locale, parameters: parameters)
    }

    public init(
        locale: Locale,
        systemPrompt: String,
        proposalPrompt: String? = nil,
        parameters: DExaminationGenerationParameters
    ) {
        self.locale = locale
        self.systemPrompt = systemPrompt
        self.proposalPrompt = proposalPrompt
        self.parameters = parameters

        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.unload()
            }
        }
    }

    deinit {
        if let memoryWarningObserver {
            NotificationCenter.default.removeObserver(memoryWarningObserver)
        }
    }

    /// Brings the model up ahead of time, without waiting for a parse. Called when
    /// dictation starts: while the physician speaks, loading the weights and
    /// initializing finish in the background instead of making them wait afterwards.
    public func prewarm() {
        Task { [weak self] in
            guard let model = try? await self?.model() else { return }

            model.prewarm()
        }
    }

    public func model() async throws -> any DExaminationNeuralModelProtocol {
        if let loadedModel {
            return loadedModel
        }
        // While loading is in progress, concurrent calls wait for it instead of loading again.
        if let loadingTask {
            return try await loadingTask.value
        }

        let locale = locale
        let systemPrompt = systemPrompt
        let proposalPrompt = proposalPrompt
        let parameters = parameters
        let task = Task { () async throws -> any DExaminationNeuralModelProtocol in
            // The implementation is chosen right here rather than up front: availability
            // depends only on parameters, system and language, and re-checking loads nothing.
            if #available(iOS 26.0, *),
               DExaminationNeuralModelFoundationModels.isAvailable(locale: locale, parameters: parameters)
            {
                return DExaminationNeuralModelFoundationModels(
                    systemPrompt: systemPrompt,
                    proposalPrompt: proposalPrompt,
                    parameters: parameters
                )
            }
            if DExaminationNeuralModelMLX.isAvailable(locale: locale, parameters: parameters) {
                return try await DExaminationNeuralModelMLX(
                    systemPrompt: systemPrompt,
                    proposalPrompt: proposalPrompt,
                    parameters: parameters
                )
            }

            throw DExaminationNeuralModelError.unavailable
        }
        loadingTask = task

        defer { loadingTask = nil }
        let model = try await task.value
        loadedModel = model

        return model
    }

    public func parseProposals(request: DictationParseRequest) async throws -> DictationProposal {
        if let labeled = DictationLabeledFormParser.parse(request: request) {
            return labeled
        }
        let explicit = DictationExplicitFactsExtractor.extract(request: request)
        if explicit.count == request.allowedFields.count {
            return DictationProposal(
                source: .explicitFacts, proposals: explicit, unmappedFindings: [], rejectedFieldIds: []
            )
        }
        do {
            let generated = try await model().parseProposals(request: request)
            guard !explicit.isEmpty else { return generated }
            var byId = Dictionary(uniqueKeysWithValues: generated.proposals.map { ($0.id, $0) })
            for field in explicit {
                byId[field.id] = field
            }
            return DictationProposal(
                source: .localModel,
                proposals: request.allowedFields.compactMap { byId[$0] },
                unmappedFindings: generated.unmappedFindings,
                rejectedFieldIds: generated.rejectedFieldIds.filter { byId[$0] == nil }
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            guard !explicit.isEmpty else { throw error }
            return DictationProposal(
                source: .explicitFacts, proposals: explicit, unmappedFindings: [], rejectedFieldIds: []
            )
        }
    }

    public func unload() {
        loadedModel = nil
    }
}
