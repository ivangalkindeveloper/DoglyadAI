extension Coordinator {
    func selectNeuralModel(
        _ model: USExaminationNeuralModel,
        onSelected: (USExaminationNeuralModel) -> Void
    ) {
        switch model.accessibility {
        case .available:
            break
        case .comingSoon, .unavailable:
            return
        }

        switch model.entitlement {
        case .base:
            dismissSheet()
            onSelected(model)
        case .pro:
            switch getSubscriptionStatus()?.type {
            case .some(.pro):
                dismissSheet()
                onSelected(model)
            case .some(.base), .none:
                showPaywall(dismissingSheet: true)
            }
        }
    }
}
