struct AnalyticsParameters {
    static let empty = AnalyticsParameters()

    private let values: [AnalyticsParameter: AnalyticsValue]

    init(
        _ values: [AnalyticsParameter: AnalyticsValue] = [:]
    ) {
        self.values = values
    }

    func merging(
        _ other: AnalyticsParameters
    ) -> AnalyticsParameters {
        AnalyticsParameters(values.merging(other.values) { _, new in new })
    }

    var firebaseParameters: [String: Any] {
        Dictionary(uniqueKeysWithValues: values.map { key, value in
            (key.rawValue, value.firebaseValue)
        })
    }
}
