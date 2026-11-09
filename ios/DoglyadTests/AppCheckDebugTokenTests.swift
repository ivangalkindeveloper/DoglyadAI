@testable import Doglyad
import XCTest

final class AppCheckDebugTokenTests: XCTestCase {
    func testRuntimeEnvironmentIsVisibleThroughFoundation() {
        let name = "AppCheckDebugToken"
        let original = ProcessInfo.processInfo.environment[
            name,
        ]
        defer {
            if let original {
                _ = setenv(
                    name,
                    original,
                    1,
                )
            } else {
                _ = unsetenv(
                    name,
                )
            }
        }
        DAppCheckProviderFactory.configureDebugToken(
            bundleIdentifier: "com.medical.doglyad.local",
            token: "synthetic-runtime-token",
            environment: [:],
        )
        XCTAssertTrue(
            ProcessInfo.processInfo.environment[
                name,
            ] == "synthetic-runtime-token",
        )
    }

    func testLocalBundlePassesConfiguredTokenToSDKEnvironment() {
        var values: [String: String] = [:]
        DAppCheckProviderFactory.configureDebugToken(
            bundleIdentifier: "com.medical.doglyad.local",
            token: "  synthetic-local-token\n",
            environment: [:],
            setEnvironment: {
                values[
                    $0,
                ] = $1
            },
        )
        XCTAssertEqual(
            values,
            ["AppCheckDebugToken": "synthetic-local-token"],
        )
    }

    func testExplicitSDKTokenKeepsPriorityOverBundledToken() {
        for name in ["AppCheckDebugToken", "FIRAAppCheckDebugToken"] {
            var isWritten = false
            DAppCheckProviderFactory.configureDebugToken(
                bundleIdentifier: "com.medical.doglyad.local",
                token: "synthetic-local-token",
                environment: [name: "synthetic-override"],
                setEnvironment: { _, _ in
                    isWritten = true
                },
            )
            XCTAssertFalse(
                isWritten,
            )
        }
    }

    func testOtherBundlesNeverInjectLocalDebugToken() {
        for identifier in [nil, "com.medical.doglyad.development", "com.medical.doglyad"] {
            var isWritten = false
            DAppCheckProviderFactory.configureDebugToken(
                bundleIdentifier: identifier,
                token: "synthetic-local-token",
                environment: [:],
                setEnvironment: { _, _ in
                    isWritten = true
                },
            )
            XCTAssertFalse(
                isWritten,
            )
        }
    }

    func testMissingBlankAndUnresolvedBuildSettingsAreIgnored() {
        for token in [nil, "", " \n", "$(APP_CHECK_DEBUG_TOKEN)", "${APP_CHECK_DEBUG_TOKEN}"] {
            var isWritten = false
            DAppCheckProviderFactory.configureDebugToken(
                bundleIdentifier: "com.medical.doglyad.local",
                token: token,
                environment: [:],
                setEnvironment: { _, _ in
                    isWritten = true
                },
            )
            XCTAssertFalse(
                isWritten,
            )
        }
    }
}
