enum SubscriptionRestoreStrategy {
    case completed(isOwnerChanged: Bool)
    case recoveryKeyRequired
}
