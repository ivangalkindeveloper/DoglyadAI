@frozen public enum DictationCompletion: String, Sendable {
    case finished
    case timedOut = "timed_out"
    case interrupted
    case cancelled
    case failed
}
