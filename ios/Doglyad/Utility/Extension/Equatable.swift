extension Equatable {
    @MainActor
    func isEqual(
        to other: Any,
    ) -> Bool {
        guard let other = other as? Self else { return false }
        return self == other
    }
}
