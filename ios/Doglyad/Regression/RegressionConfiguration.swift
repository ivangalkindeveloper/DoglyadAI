#if DEBUG && DOGLYAD_REGRESSION
    import Foundation

    enum RegressionConfiguration {
        /// Changes only version policy after the real App Check protected download.
        static func apply(
            to configuration: ApplicationConfig,
        ) throws -> ApplicationConfig {
            let mode = UserDefaults.standard.string(
                forKey: "regressionVersionPolicy",
            ) ?? ""
            guard mode == "major" || mode == "minor" else {
                return configuration
            }
            var document = try JSONSerialization.jsonObject(
                with: JSONEncoder().encode(
                    configuration,
                ),
            ) as! [String: Any]
            let current = Bundle.shortVersion
            document[
                "actualVersion",
            ] = ["major": current.major + (mode == "major" ? 1 : 0), "minor": current.minor + 1, "patch": current.patch]
            return try JSONDecoder().decode(
                ApplicationConfig.self,
                from: JSONSerialization.data(
                    withJSONObject: document,
                ),
            )
        }
    }
#endif
