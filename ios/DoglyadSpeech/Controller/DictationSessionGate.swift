import Foundation

/// Keeps callbacks from a cancelled or previous recording out of the current one.
struct DictationSessionGate {
    private(set) var activeID: UUID?
    private(set) var isFinalizing = false

    mutating func start() -> UUID? {
        guard activeID == nil else { return nil }
        let id = UUID()
        activeID = id
        return id
    }

    func acceptsResult(for id: UUID) -> Bool {
        activeID == id
    }

    mutating func beginFinalization(for id: UUID) -> Bool {
        guard activeID == id, !isFinalizing else { return false }
        isFinalizing = true
        return true
    }

    mutating func finish(for id: UUID) -> Bool {
        guard activeID == id, isFinalizing else { return false }
        activeID = nil
        isFinalizing = false
        return true
    }

    @discardableResult
    mutating func cancel() -> UUID? {
        let id = activeID
        activeID = nil
        isFinalizing = false
        return id
    }
}
