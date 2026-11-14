@MainActor
protocol PatientConsentStateProtocol: AnyObject {
    var isDoNotAskAgain: Bool {
        get
    }

    func copyWith(
        isDoNotAskAgain: Bool?,
    ) -> Self
}
