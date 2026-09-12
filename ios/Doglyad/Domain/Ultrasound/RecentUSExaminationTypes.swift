enum RecentUSExaminationTypes {
    static let maximumCount = 3

    static func recording(
        _ id: String,
        in existingIds: [String]
    ) -> [String] {
        Array(([id] + existingIds.filter { $0 != id }).prefix(maximumCount))
    }

    static func available(
        from existingIds: [String],
        availableIds: Set<String>
    ) -> [String] {
        var seenIds: Set<String> = []
        let visibleIds = existingIds.filter { id in
            availableIds.contains(id) && seenIds.insert(id).inserted
        }
        return Array(visibleIds.prefix(maximumCount))
    }
}
