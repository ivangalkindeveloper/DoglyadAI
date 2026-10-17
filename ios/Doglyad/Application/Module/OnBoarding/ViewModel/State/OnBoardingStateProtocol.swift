@MainActor
protocol OnBoardingStateProtocol: AnyObject {
    var index: Int { get }
    var primaryButtonTitleKey: L10NKey { get }
}
