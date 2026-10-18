@frozen public enum DSpeechModelPreparationStatus: Equatable {
    case checking
    case downloading(progress: Double?)
    case loading
    case ready
    case failed
}
