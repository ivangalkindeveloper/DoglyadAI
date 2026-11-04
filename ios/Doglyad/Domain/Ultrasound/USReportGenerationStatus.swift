enum USReportGenerationStatus: String, Codable, Sendable {
    case generating, completed, interrupted, failed, cancelled

    var isCompleted: Bool {
        self == .completed
    }

    var isRecoverable: Bool {
        self == .generating || self == .interrupted
    }
}
