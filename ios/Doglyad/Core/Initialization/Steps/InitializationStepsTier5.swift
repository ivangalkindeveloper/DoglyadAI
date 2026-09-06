import DependencyInitializer
import Foundation

extension InitializationProcess {
    static let stepsTier5 = StepSet(
        sync: [
            SyncInitializationStep<InitializationProcess>(
                title: "Check selected ultrasound examination type",
                run: { (process: InitializationProcess) in
                    @MainActor
                    func setDefault() {
                        process.ultrasoundConclusionRepository!.setSelectedExaminationTypeId(
                            id: process.usExaminationTypeDefault!.id
                        )
                    }

                    let usExaminationTypeId = process.ultrasoundConclusionRepository!.getSelectedExaminationTypeId()
                    guard usExaminationTypeId != nil else {
                        return
                    }

                    let matchedId = process.usExaminationTypesById![usExaminationTypeId!]
                    guard matchedId != nil else {
                        return setDefault()
                    }
                }
            ),
            SyncInitializationStep<InitializationProcess>(
                title: "Check selected ultrasound selected neural model",
                run: { (process: InitializationProcess) in
                    @MainActor
                    func setDefault() {
                        process.ultrasoundModelRepository!.setSelectedModelId(
                            id: process.usExaminationNeuralModelDefault!.id
                        )
                    }

                    let selectedUSExaminationNeuralModelId = process.ultrasoundModelRepository!.getSelectedModelId()
                    guard selectedUSExaminationNeuralModelId != nil else {
                        return setDefault()
                    }

                    let selectedModel = process.usExaminationNeuralModelsById![selectedUSExaminationNeuralModelId!]
                    guard let selectedModel else {
                        return setDefault()
                    }

                    @MainActor
                    func selectFirstAvailableBaseModel() {
                        let firstBaseModel = process.usExaminationNeuralModels!.first(where: {
                            let isAvailable: Bool
                            switch $0.accessibility {
                            case .available:
                                isAvailable = true
                            case .comingSoon, .unavailable:
                                isAvailable = false
                            }

                            switch $0.entitlement {
                            case .base:
                                return isAvailable
                            case .pro:
                                return false
                            }
                        })
                        process.ultrasoundModelRepository!.setSelectedModelId(
                            id: (firstBaseModel ?? process.usExaminationNeuralModelDefault!).id
                        )
                    }

                    switch selectedModel.accessibility {
                    case .available:
                        break
                    case .comingSoon, .unavailable:
                        return selectFirstAvailableBaseModel()
                    }

                    let activeSubscriptionType = process.initialSubscriptionStatus?.type
                    let isModelEntitlementAvailable: Bool
                    switch selectedModel.entitlement {
                    case .base:
                        isModelEntitlementAvailable = true
                    case .pro:
                        switch activeSubscriptionType {
                        case .some(.pro):
                            isModelEntitlementAvailable = true
                        case .some(.base), .none:
                            isModelEntitlementAvailable = false
                        }
                    }
                    guard isModelEntitlementAvailable else {
                        return selectFirstAvailableBaseModel()
                    }
                }
            ),
            SyncInitializationStep<InitializationProcess>(
                title: "Initial screen",
                run: { (process: InitializationProcess) in
                    if !process.applicationConfig!.isServiceAvailable {
                        throw InitializationError.serviceUnavailable(
                            email: process.applicationConfig!.contactEmail
                        )
                    }

                    if Bundle.shortVersion.major < process.applicationConfig!.actualVersion.major, process.applicationConfig?.appStoreId != nil {
                        return process.initialScreen = .newVersion
                    }

                    let isOnBoardingCompleted = process.database!.getOnBoardingCompleted()
                    let selectedUSExaminationTypeId = process.database!.getSelectedUSExaminationTypeId()
                    if !isOnBoardingCompleted || selectedUSExaminationTypeId == nil {
                        return process.initialScreen = .onBoarding
                    }

                    // The documents changed since the last acceptance — consent has to be
                    // taken again, otherwise there is no evidence that the new revision
                    // was accepted.
                    let acceptedLegalDate = process.database!.getAcceptedLegalDocumentDate() ?? .distantPast
                    if acceptedLegalDate < process.applicationConfig!.legalDate {
                        return process.initialScreen = .legalUpdate
                    }

                    if process.initialUltraSoundConclusionsCount == 0, process.initialSubscriptionStatus == nil {
                        return process.initialScreen = .subscriptionPaywall
                    }

                    process.initialScreen = .scan
                }
            ),
            SyncInitializationStep<InitializationProcess>(
                title: "Application version",
                run: { (process: InitializationProcess) in
                    let version = Bundle.shortVersion
                    process.version = "\(version.major).\(version.minor).\(version.patch)"
                }
            ),
        ]
    )
}
