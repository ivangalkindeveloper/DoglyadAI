enum AnalyticsValue {
    case bool(Bool)
    case double(Double)
    case int(Int)
    case string(String)

    var firebaseValue: Any {
        switch self {
        case let .bool(value):
            value
        case let .double(value):
            value
        case let .int(value):
            value
        case let .string(value):
            value
        }
    }
}
