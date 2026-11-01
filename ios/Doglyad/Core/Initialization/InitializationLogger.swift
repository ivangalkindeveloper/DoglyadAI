import Foundation
import OSLog

enum InitializationLogger {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Doglyad",
        category: "Initialization",
    )

    static func logFailure(
        step: String?,
        error: any Error,
    ) {
        let reason = failureDescription(
            error,
        )
        logger.error(
            "Initialization failed: step=\(step ?? "unnamed", privacy: .public) reason=\(reason, privacy: .public)",
        )
    }

    private static func failureDescription(
        _ error: any Error,
    ) -> String {
        switch error {
        case let error as L10NError:
            return switch error {
            case let .missingKey(
                key,
            ):
                "missing localization key: \(key.rawValue)"
            }
        case let DecodingError.keyNotFound(
            key,
            context,
        ):
            return "missing configuration key: \((context.codingPath + [key]).map(\.stringValue).joined(separator: "."))"
        case let DecodingError.typeMismatch(
            _,
            context,
        ),
        let DecodingError.valueNotFound(
            _,
            context,
        ),
        let DecodingError.dataCorrupted(
            context,
        ):
            return "invalid configuration at: \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        default:
            // Error descriptions and userInfo can contain request headers or server data.
            let failure = error as NSError
            return "\(String(reflecting: type(of: error))) domain=\(failure.domain) code=\(failure.code)"
        }
    }
}
