@testable import Doglyad
import Foundation
import Testing

struct L10NTests {
    @Test(
        arguments: ["en", "ru"],
    )
    func resourcesRenderTheSelectedServerText(
        code: String,
    ) throws {
        let l10n = try VoiceLocalizationTestSupport.l10n(
            code: code,
        )
        #expect(
            String(
                localized: l10n[
                    .buttonSpeech,
                ],
            ) == l10n.text(
                .buttonSpeech,
            ),
        )
        #expect(
            l10n.voice.code == code,
        )
        #expect(
            l10n.locale.language.languageCode?.identifier == code,
        )
        #expect(
            l10n.text(
                .scanPatientDefaultNameLabel,
                values: ["count": "12"],
            ).hasSuffix(
                "#12",
            ),
        )
        #expect(
            String(
                localized: l10n.resource(
                    .photoViewPage,
                    values: ["current": "2", "total": "7"],
                ),
            ) == l10n.text(
                .photoViewPage,
                values: ["current": "2", "total": "7"],
            ),
        )
    }

    @Test
    func interpolationTreatsUserDataAsLiteralText() throws {
        let l10n = try VoiceLocalizationTestSupport.l10n(
            code: "ru",
        )
        let prefix = "💊 100% %@ {email}"
        let email = "doctor+%lld@example.com"
        let value = l10n.text(
            .shareUserEmailTitle,
            values: ["prefix": prefix, "email": email],
        )
        #expect(
            value == "\(prefix) \(email)",
        )
        #expect(
            String(
                localized: l10n.resource(
                    .shareUserEmailTitle,
                    values: ["prefix": prefix, "email": email],
                ),
            ) == value,
        )
        // Braces inside the report example are content, not UI arguments.
        #expect(
            l10n.text(
                .templateExampleDescription,
            ).contains(
                "{{organ}}",
            ),
        )
    }

    @Test(
        arguments: [false, true],
    )
    func missingOrEmptyKnownKeyRejectsTheCatalog(
        empty: Bool,
    ) throws {
        var strings = try strings(
            code: "en",
        )
        if empty {
            strings[
                L10NKey.buttonSpeech.rawValue,
            ] = " \n "
        } else {
            strings.removeValue(
                forKey: L10NKey.buttonSpeech.rawValue,
            )
        }
        let localization = try Localization(
            code: "en",
            strings: strings,
            voice: VoiceLocalizationTestSupport.load(
                locale: Locale(
                    identifier: "en",
                ),
            ),
        )
        #expect(
            throws: L10NError.self,
        ) { try L10N(
            localization: localization,
        ) }
    }

    @Test
    func extraServerKeysAllowAnOlderClientToKeepWorking() throws {
        var strings = try strings(
            code: "en",
        )
        strings[
            "futureServerKey",
        ] = "Future catalog value"
        let localization = try Localization(
            code: "en",
            strings: strings,
            voice: VoiceLocalizationTestSupport.load(
                locale: Locale(
                    identifier: "en",
                ),
            ),
        )
        let l10n = try L10N(
            localization: localization,
        )
        #expect(
            l10n.text(
                .buttonSpeech,
            ) == strings[
                L10NKey.buttonSpeech.rawValue,
            ],
        )
    }

    @Test
    func initializationErrorHasLocalTextWithoutALoadedCatalog() {
        let resource = LocalizedStringResource(
            "errorUnknownTitle",
            locale: Locale(
                identifier: "ru",
            ),
        )
        #expect(
            String(
                localized: resource,
            ) == "Неизвестная ошибка",
        )
    }

    private func strings(
        code: String,
    ) throws -> [String: String] {
        try JSONDecoder().decode(
            [String: String].self,
            from: VoiceLocalizationTestSupport.data(
                kind: "strings",
                code: code,
            ),
        )
    }
}
