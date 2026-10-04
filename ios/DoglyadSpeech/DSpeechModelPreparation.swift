@frozen public enum DSpeechModelPreparation: Equatable {
    case checking
    case downloading(progress: Double?)
    case loading
    case ready
    case failed
}
