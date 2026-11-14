#if DEBUG
    enum SubscriptionManagePreviewScenario: String, CaseIterable {
        case autoRenewalDisabledSuccess, recoveredAccess, purchaseCompletedSuccess, appleBase, applePro, appleRenewalOff, robokassaBase, robokassaPro, renewalOff, inactive, loading, updating, failed, operationFailed, restoring, managing, refunding
    }
#endif
