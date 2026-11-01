import FirebaseAppCheck
import FirebaseCore
import Foundation
import FoundationModels
import XCTest

final class VoiceMatrixAppCheckTests: XCTestCase {
    @MainActor
    func testFoundationAvailability() throws {
        guard ProcessInfo.processInfo.environment[
            "VOICE_MATRIX_AVAILABILITY",
        ] == "1" else {
            throw XCTSkip(
                "Explicit device availability probe only",
            )
        }
        guard #available(iOS 26.0, *) else { throw XCTSkip(
            "Foundation Models requires iOS 26",
        ) }
        let model = SystemLanguageModel.default
        let result: [String: Any] = [
            "availability": String(
                describing: model.availability,
            ),
            "isAvailable": model.isAvailable,
            "supportsEnglish": model.supportsLocale(
                Locale(
                    identifier: "en",
                ),
            ),
            "supportsRussian": model.supportsLocale(
                Locale(
                    identifier: "ru",
                ),
            ),
            "systemLocale": Locale.current.identifier,
        ]
        let directory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask,
        )[
            0,
        ]
        try JSONSerialization.data(
            withJSONObject: result,
            options: [.sortedKeys],
        ).write(
            to: directory.appendingPathComponent(
                "voice-matrix-foundation-status.json",
            ),
            options: .atomic,
        )
        print(
            "VOICE_MATRIX_FOUNDATION_STATUS=\(result)",
        )
    }

    @MainActor
    func testExportTokenForLocalBenchmark() async throws {
        guard ProcessInfo.processInfo.environment[
            "VOICE_MATRIX_EXPORT_TOKEN",
        ] == "1" else {
            throw XCTSkip(
                "Explicit local benchmark token export only",
            )
        }
        #if DEBUG || targetEnvironment(
            simulator,
        )
        throw XCTSkip(
            "Use Release-Development on a physical iPhone for real App Attest",
        )
        #else
        for _ in 0 ..< 100 where FirebaseApp.app() == nil {
            try await Task.sleep(
                for: .milliseconds(
                    100,
                ),
            )
        }
        XCTAssertNotNil(
            FirebaseApp.app(),
        )
        let isKeepingAlive = ProcessInfo.processInfo.environment[
            "VOICE_MATRIX_TOKEN_KEEPALIVE",
        ] == "1"
        repeat {
            let token = try await AppCheck.appCheck().token(
                forcingRefresh: true,
            )
            let directory = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask,
            )[
                0,
            ]
            let destination = directory.appendingPathComponent(
                "voice-matrix-app-check-token.txt",
            )
            try token.token.write(
                to: destination,
                atomically: true,
                encoding: .utf8,
            )
            print(
                "VOICE_MATRIX_APP_CHECK_EXPORTED",
            )
            if isKeepingAlive {
                try await Task.sleep(
                    for: .seconds(
                        1200,
                    ),
                )
            }
        } while isKeepingAlive
        #endif
    }
}
