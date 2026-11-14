import Combine
import DoglyadNetwork
import Foundation
import Handler

@MainActor
final class SubscriptionRootViewModel: DStateViewModel<any SubscriptionRootStateProtocol> {
    private let container: DependencyContainer
    private let getStoredSettingsAI: () -> SettingsAI
    private let repositoryFactory: SubscriptionRepositoryFactoryProtocol
    private var transactionUpdates: Task<Void, Never>?
    private var reconciliationTask: Task<Void, Never>?
    private var purchaseTask: Task<SubscriptionPurchaseOutcome, Error>?
    private var purchaseID: UUID?
    private var identityOperationID: UUID?
    private var pendingPurchaseID: UUID?
    private var pendingPlan: SubscriptionPlan?
    private var pendingContext: SubscriptionPurchaseContextProtocol?
    private var pendingOutcome: SubscriptionPurchaseOutcome = .pending
    private var identityRevision = UUID()
    private var isInitialized = false

    init(
        container: DependencyContainer,
        getStoredSettingsAI: (() -> SettingsAI)? = nil,
    ) {
        self.container = container
        self.getStoredSettingsAI = getStoredSettingsAI ?? {
            container.initialSettingsAI
        }
        repositoryFactory = container.subscriptionRepositoryFactory
        let state: any SubscriptionRootStateProtocol = switch container.initialSubscriptionStatus {
        case let .some(
            status,
        ):
            SubscriptionRootActiveState(
                status: status,
            )
        case .none: SubscriptionRootInactiveState()
        }
        super.init(
            state: state,
        )
    }

    var status: SubscriptionStatus? {
        switch state {
        case let state as SubscriptionRootActiveState: state.status
        case _ as SubscriptionRootInactiveState: nil
        default:
            preconditionFailure(
                "Unexpected subscription root state",
            )
        }
    }

    func onInit() {
        guard !isInitialized else {
            return
        }
        isInitialized = true
        let storeKit = container.subscriptionStoreKitRepository
        transactionUpdates = Task { [weak self] in
            do {
                try await storeKit.observeChanges { [weak self] result in
                    self?.handle {
                        let update = try result.get()
                        if update.isOwnerChanged {
                            self?.invalidateIdentity()
                        }
                        self?.acceptTransaction(
                            update,
                        )
                        _ = try await self?.fetchStatus()
                    }
                }
            } catch is CancellationError {} catch {
                self?.handle {
                    throw error
                }
            }
        }
        reconciliationTask = handle { [weak self] in
            let isOwnerChanged = try await storeKit.synchronizeCurrentEntitlements()
            if isOwnerChanged {
                self?.invalidateIdentity()
            }
            _ = try await self?.fetchStatus()
        }
    }

    deinit {
        transactionUpdates?.cancel()
        reconciliationTask?.cancel()
        purchaseTask?.cancel()
    }

    func purchase(
        plan: SubscriptionPlan,
        isAutoRenewing: Bool = true,
    ) async throws -> SubscriptionPurchaseOutcome {
        guard purchaseID == nil, identityOperationID == nil else {
            throw SubscriptionError.purchasePending
        }
        if pendingPlan?.id == plan.id, pendingPlan?.source == plan.source,
           let outcome = try await checkPendingPurchase(
               {
                   try await $0.resume()
               },
           )
        {
            switch outcome {
            case .completed:
                return try await checkPurchase()
            case .pending:
                return .pending
            case .cancelled:
                clearPendingPurchase()
            }
        }
        try Task.checkCancellation()
        let selected = await repositoryFactory.make()
        try Task.checkCancellation()
        guard purchaseID == nil, identityOperationID == nil else {
            throw SubscriptionError.purchasePending
        }
        let id = UUID()
        let revision = identityRevision
        purchaseID = id
        pendingPurchaseID = id
        pendingPlan = plan
        pendingContext = nil
        pendingOutcome = .pending
        let task = Task { [weak self] () throws -> SubscriptionPurchaseOutcome in
            let result = try await selected.purchase(
                plan: plan,
                isAutoRenewing: isAutoRenewing,
            ) { [weak self] context in
                guard let self, purchaseID == id, identityRevision == revision, !Task.isCancelled else {
                    return
                }
                pendingContext = context
            }
            try Task.checkCancellation()
            guard let self, identityRevision == revision else {
                throw CancellationError()
            }
            guard pendingPurchaseID == id else {
                throw CancellationError()
            }
            switch result {
            case .completed:
                pendingOutcome = result
                let status = try await fetchStatus()
                return resolvePendingPurchase(
                    status: status,
                )
            case .pending:
                return .pending
            case .cancelled:
                clearPendingPurchase()
                return .cancelled
            }
        }
        purchaseTask = task
        defer {
            if purchaseID == id {
                purchaseID = nil
                purchaseTask = nil
            }
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    func restorePurchases() async throws -> SubscriptionRestoreStrategy {
        guard purchaseID == nil, identityOperationID == nil else {
            throw SubscriptionError.purchasePending
        }
        identityOperationID = UUID()
        defer {
            identityOperationID = nil
        }
        let repository: SubscriptionRepositoryProtocol
        switch status?.source {
        case .apple:
            repository = container.subscriptionStoreKitRepository
        case .robokassa:
            return .recoveryKeyRequired
        case .none:
            repository = await repositoryFactory.make()
        }
        try Task.checkCancellation()
        let strategy = try await repository.restorePurchases()
        switch strategy {
        case let .completed(
            isOwnerChanged,
        ):
            if isOwnerChanged {
                invalidateIdentity()
            }
            _ = try await fetchStatus()
        case .recoveryKeyRequired:
            break
        }
        return strategy
    }

    func manageSubscription() async throws {
        guard status?.source != .robokassa else {
            throw SubscriptionError.offeringsUnavailable
        }
        let selected = container.subscriptionStoreKitRepository
        try await selected.manageSubscription()
        _ = try await fetchStatus()
    }

    func requestRefund() async throws {
        guard status?.source != .robokassa else {
            throw SubscriptionError.offeringsUnavailable
        }
        let subscriptionRepository = container.subscriptionStoreKitRepository
        try await subscriptionRepository.requestRefund()
        _ = try await fetchStatus()
    }

    func setAutoRenewal(
        isAutoRenewing: Bool,
    ) async throws {
        guard purchaseID == nil, identityOperationID == nil else {
            throw SubscriptionError.purchasePending
        }
        identityOperationID = UUID()
        defer {
            identityOperationID = nil
        }
        let revision = identityRevision
        let status = try await container.subscriptionBackendRepository.setAutoRenewal(
            isAutoRenewing: isAutoRenewing,
            configEntitlements: container.applicationConfig.entitlements,
        )
        guard identityRevision == revision else {
            throw CancellationError()
        }
        update(
            status: status,
        )
    }

    func recover(
        key: String,
    ) async throws -> SubscriptionStatus? {
        guard purchaseID == nil, identityOperationID == nil else {
            throw SubscriptionError.purchasePending
        }
        identityOperationID = UUID()
        defer {
            identityOperationID = nil
        }
        let status = try await container.subscriptionBackendRepository.recover(
            key: key,
            configEntitlements: container.applicationConfig.entitlements,
        )
        invalidateIdentity()
        update(
            status: status,
        )
        return status
    }

    func fetchStatus() async throws -> SubscriptionStatus? {
        let revision = identityRevision
        if pendingContext != nil {
            _ = try await checkPendingPurchase {
                try await $0.check()
            }
        }
        let status = try await container.subscriptionBackendRepository.fetchStatus(
            configEntitlements: container.applicationConfig.entitlements,
        )
        guard identityRevision == revision else {
            throw CancellationError()
        }
        update(
            status: status,
        )
        return status
    }

    func checkPurchase() async throws -> SubscriptionPurchaseOutcome {
        let pendingID = pendingPurchaseID
        switch try await checkPendingPurchase(
            {
                try await $0.check()
            },
        ) {
        case .some(
            .pending,
        ), .none:
            return .pending
        case .some(
            .cancelled,
        ):
            clearPendingPurchase()
            return .cancelled
        case .some(
            .completed,
        ):
            let status = try await fetchStatus()
            guard pendingPurchaseID == pendingID else {
                return .pending
            }
            return resolvePendingPurchase(
                status: status,
            )
        }
    }

    func observeStatus(
        _ observer: @escaping (SubscriptionStatus?) -> Void,
    ) -> AnyCancellable {
        $state.map { state -> SubscriptionStatus? in
            switch state {
            case let state as SubscriptionRootActiveState: state.status
            case _ as SubscriptionRootInactiveState: nil
            default:
                preconditionFailure(
                    "Unexpected subscription root state",
                )
            }
        }.sink(
            receiveValue: observer,
        )
    }

    func resolveSettingsAI() -> SettingsAI {
        let neuralModelConfig = container.applicationConfig.ultrasound.neuralModel
        let settings = getStoredSettingsAI()
        if status?.isReportGenerationSettingsAvailable == true {
            return SettingsAI(
                transcriberType: settings.transcriberType,
                transcriptParserType: settings.transcriptParserType,
                selectedNeuralModelId: settings.selectedNeuralModelId,
                isMarkdown: settings.isMarkdown,
                temperature: settings.temperature ?? neuralModelConfig.temperature,
                maxTokens: settings.maxTokens ?? neuralModelConfig.maxTokens,
            )
        }
        return SettingsAI(
            transcriberType: settings.transcriberType,
            transcriptParserType: settings.transcriptParserType,
            selectedNeuralModelId: settings.selectedNeuralModelId,
            isMarkdown: false,
            temperature: neuralModelConfig.temperature,
            maxTokens: neuralModelConfig.maxTokens,
        )
    }

    func refreshStatus() async {
        let task = handle {
            _ = try await self.fetchStatus()
        }
        await task?.value
    }

    func update(
        status: SubscriptionStatus?,
    ) {
        switch status {
        case let .some(
            status,
        ):
            emit(
                SubscriptionRootActiveState(
                    status: status,
                ),
            )
        case .none:
            emit(
                SubscriptionRootInactiveState(),
            )
        }
    }

    private func invalidateIdentity() {
        identityRevision = UUID()
        clearPendingPurchase()
        purchaseTask?.cancel()
    }

    private func acceptTransaction(
        _ update: SubscriptionTransactionUpdate,
    ) {
        guard let result = pendingContext?.check(
            transaction: update,
        ) else {
            return
        }
        pendingOutcome = result
    }

    private func resolvePendingPurchase(
        status: SubscriptionStatus?,
    ) -> SubscriptionPurchaseOutcome {
        guard pendingContext != nil else {
            return .pending
        }
        switch pendingOutcome {
        case .pending:
            return .pending
        case .cancelled:
            clearPendingPurchase()
            return .cancelled
        case .completed:
            guard let status else {
                return .pending
            }
            clearPendingPurchase()
            return .completed(
                status,
            )
        }
    }

    private func clearPendingPurchase() {
        pendingPurchaseID = nil
        pendingPlan = nil
        pendingContext = nil
        pendingOutcome = .pending
    }

    private func checkPendingPurchase(
        _ operation: (SubscriptionPurchaseContextProtocol) async throws -> SubscriptionPurchaseOutcome?,
    ) async throws -> SubscriptionPurchaseOutcome? {
        guard let context = pendingContext else {
            return nil
        }
        switch pendingOutcome {
        case .completed, .cancelled:
            return pendingOutcome
        case .pending:
            break
        }
        let revision = identityRevision
        let pendingID = pendingPurchaseID
        let result: SubscriptionPurchaseOutcome?
        do {
            result = try await operation(
                context,
            )
        } catch {
            guard identityRevision == revision, pendingPurchaseID == pendingID else {
                throw CancellationError()
            }
            throw error
        }
        guard identityRevision == revision, pendingPurchaseID == pendingID else {
            throw CancellationError()
        }
        switch pendingOutcome {
        case .completed, .cancelled:
            return pendingOutcome
        case .pending:
            if let result {
                pendingOutcome = result
            }
            return result
        }
    }
}
