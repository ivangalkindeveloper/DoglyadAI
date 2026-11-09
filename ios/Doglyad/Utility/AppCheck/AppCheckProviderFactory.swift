import FirebaseAppCheck
import FirebaseCore
import Foundation

class DAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(
        with app: FirebaseApp,
    ) -> AppCheckProvider? {
        #if DEBUG || targetEnvironment(
            simulator,
        )
        return AppCheckDebugProvider(
            app: app,
        )
        #else
        return AppAttestProvider(
            app: app,
        )
        #endif
    }

    static func configureDebugToken(
        bundleIdentifier: String? = Bundle.main.bundleIdentifier,
        token: String? = Bundle.dictionaryString(
            .APP_CHECK_DEBUG_TOKEN,
        ),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        setEnvironment: (String, String) -> Void = { name, value in
            _ = setenv(
                name,
                value,
                1,
            )
        },
    ) {
        #if DEBUG
            guard bundleIdentifier == "com.medical.doglyad.local",
                  environment[
                      "AppCheckDebugToken",
                  ] == nil,
                  environment[
                      "FIRAAppCheckDebugToken",
                  ] == nil,
                  let token = token?.trimmingCharacters(
                      in: .whitespacesAndNewlines,
                  ),
                  !token.isEmpty,
                  !token.contains(
                      "$(",
                  ),
                  !token.contains(
                      "${",
                  )
            else {
                return
            }
            setEnvironment(
                "AppCheckDebugToken",
                token,
            )
        #endif
    }
}
