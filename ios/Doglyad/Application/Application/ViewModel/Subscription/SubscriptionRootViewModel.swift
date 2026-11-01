import Combine
import DoglyadNetwork
import Foundation
import Handler

@MainActor
final class SubscriptionRootViewModel: DStateViewModel<any SubscriptionRootStateProtocol> {
    private let container: DependencyContainer
    private let getStoredSettingsAI: () -> SettingsAI
    private let repositoryFactory: SubscriptionRepositoryFactory
    private var transactionUpdates: Task<Void, Never>?
    private var reconciliationTask: Task<Void, Never>?
    private var purchaseTask: Task<SubscriptionPurchaseOutcome, Error>?
    private var purchaseID: UUID?
    private var identityOperationID: UUID?
    private var pendingPurchaseID: UUID?
    private var pendingPlan: SubscriptionPlan?
    private var pendingReference: SubscriptionPurchaseReference?
    private var pendingPayment: BillingPaymentResponse?
    private var isPendingApplePurchaseVerified = false
    private var identityRevision = UUID()
    private var isInitialized = false

    init(
        container: DependencyContainer,
        getStoredSettingsAI: (() -> SettingsAI)? = nil,
    ) {
        self.container = container
        repositoryFactory = container.subscriptionRepositoryFactory
        self.getStoredSettingsAI = getStoredSettingsAI ?? {
            container.initialSettingsAI
        }
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
        let factory = repositoryFactory
        transactionUpdates = Task { [weak self] in
            do {
                let storeKit = factory.make(
                    source: .apple,
                )
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
            let storeKit = factory.make(
                source: .apple,
            )
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
    ) async throws -> SubscriptionPurchaseOutcome {
        guard purchaseID == nil, identityOperationID == nil else {
            throw SubscriptionError.purchasePending
        }
        try Task.checkCancellation()
        let selected = try await repositoryFactory.make(
            plan: plan,
        )
        try Task.checkCancellation()
        guard purchaseID == nil, identityOperationID == nil else {
            throw SubscriptionError.purchasePending
        }
        let id = UUID()
        let revision = identityRevision
        purchaseID = id
        pendingPurchaseID = id
        pendingPlan = plan
        pendingReference = nil
        pendingPayment = nil
        isPendingApplePurchaseVerified = false
        let task = Task { [weak self] () throws -> SubscriptionPurchaseOutcome in
            let result = try await selected.purchase(
                plan: plan,
            ) { [weak self] reference in
                guard let self, purchaseID == id, identityRevision == revision, !Task.isCancelled else {
                    return
                }
                pendingReference = reference
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
                switch pendingReference {
                case .apple: isPendingApplePurchaseVerified = true
                case .yookassa, .none: break
                }
            case .pending, .cancelled: break
            }
            let status = try await fetchStatus()
            switch result {
            case .completed, .pending:
                return resolvePendingPurchase(
                    status: status,
                )
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

    func restorePurchases() async throws -> SubscriptionStatus? {
        guard purchaseID == nil, identityOperationID == nil else {
            throw SubscriptionError.purchasePending
        }
        identityOperationID = UUID()
        defer {
            identityOperationID = nil
        }
        // Existing Apple purchases remain restorable after changing the storefront.
        let selected = repositoryFactory.make(
            source: .apple,
        )
        if try await selected.restorePurchases() {
            invalidateIdentity()
        }
        return try await fetchStatus()
    }

    func manageSubscription() async throws {
        let selected = repositoryFactory.make(
            source: status?.source,
        )
        try await selected.manageSubscription()
        _ = try await fetchStatus()
    }

    func requestRefund() async throws {
        let subscriptionRepository = repositoryFactory.make(
            source: status?.source,
        )
        try await subscriptionRepository.requestRefund()
        _ = try await fetchStatus()
    }

    func createRecoveryKey() async throws -> String {
        try await container.subscriptionBackendRepository.createRecoveryKey()
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
        try await container.subscriptionBackendRepository.recover(
            key: key,
        )
        invalidateIdentity()
        return try await fetchStatus()
    }

    func fetchStatus() async throws -> SubscriptionStatus? {
        let revision = identityRevision
        let pendingID = pendingPurchaseID
        switch pendingReference {
        case let .yookassa(
            paymentID,
        ):
            switch pendingPayment?.status {
            case .succeeded, .canceled, .refunded: break
            case .awaitingToken, .created, .pending, .needsReview, .none:
                let payment = try await container.subscriptionBackendRepository.checkPayment(
                    id: paymentID,
                    isAbandoned: false,
                )
                guard identityRevision == revision, pendingPurchaseID == pendingID else {
                    throw CancellationError()
                }
                guard payment.id == paymentID, payment.planId == pendingPlan?.id else {
                    throw SubscriptionError.unverifiedTransaction
                }
                pendingPayment = payment
            }
        case .apple, .none: break
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
        switch pendingReference {
        case .yookassa: pendingPayment = nil
        case .apple, .none: break
        }
        let status = try await fetchStatus()
        guard pendingPurchaseID == pendingID else {
            throw CancellationError()
        }
        return resolvePendingPurchase(
            status: status,
        )
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
        guard let plan = pendingPlan else {
            return
        }
        switch pendingReference {
        case let .apple(
            previousID,
            previousDate,
        ):
            guard update.planId == plan.id, update.transactionId != previousID,
                  previousDate.map(
                      {
                          update.purchaseDate > $0
                      },
                  ) ?? true
            else {
                return
            }
            isPendingApplePurchaseVerified = update.isActive
        case .yookassa, .none: break
        }
    }

    private func resolvePendingPurchase(
        status: SubscriptionStatus?,
    ) -> SubscriptionPurchaseOutcome {
        guard let plan = pendingPlan else {
            return .pending
        }
        switch pendingReference {
        case .apple:
            guard isPendingApplePurchaseVerified else {
                return .pending
            }
        case let .yookassa(
            paymentID,
        ):
            guard let payment = pendingPayment, payment.id == paymentID, payment.planId == plan.id else {
                return .pending
            }
            switch payment.status {
            case .succeeded: break
            case .canceled, .refunded:
                clearPendingPurchase()
                return .cancelled
            case .awaitingToken, .created, .pending, .needsReview: return .pending
            }
        case .none: return .pending
        }
        guard let status else {
            return .pending
        }
        clearPendingPurchase()
        return .completed(
            status,
        )
    }

    private func clearPendingPurchase() {
        pendingPurchaseID = nil
        pendingPlan = nil
        pendingReference = nil
        pendingPayment = nil
        isPendingApplePurchaseVerified = false
    }
}
