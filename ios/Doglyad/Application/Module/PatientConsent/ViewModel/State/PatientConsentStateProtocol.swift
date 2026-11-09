@MainActor
protocol PatientConsentStateProtocol: AnyObject {
    var isDoNotAskAgain: Bool {
        get
    }
}
