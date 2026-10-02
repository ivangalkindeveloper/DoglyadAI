@testable import Doglyad
import Foundation
import Testing

struct ConfigTests {
    @Test
    func defaultApplicationConfigRoundTrips() throws {
        let data = try JSONEncoder().encode(ApplicationConfig.default)
        let config = try JSONDecoder().decode(ApplicationConfig.self, from: data)

        #expect(config.actualVersion.major == Version.default.major)
        #expect(config.locale.defaultCode == ApplicationConfig.default.locale.defaultCode)
        #expect(config.locale.codes == ApplicationConfig.default.locale.codes)
        #expect(config.network.timeoutIntervalForRequest == NetworkConfig.default.timeoutIntervalForRequest)
        #expect(config.history.pageSize == HistoryConfig.default.pageSize)
        #expect(config.ultrasound.neuralModel.maxTokens == UltrasoundNeuralModelConfig.default.maxTokens)
        #expect(
            config.ultrasound.examinationNeuralModel.maxContextTokens ==
                UltrasoundExaminationNeuralModelConfig.default.maxContextTokens
        )
    }

    @Test
    func missingConfigSectionsUseDefaults() throws {
        let data = Data(
            """
            {
                "appStoreId": "test",
                "locale": {"defaultCode": "en", "codes": ["en", "ru"]},
                "contactEmail": "test@doglyad.ru",
                "appleUpdateUrl": "https://apps.apple.com/app/id",
                "privacyPolicyUrl": "https://doglyad.ru/privacy",
                "termsAndConditionsUrl": "https://doglyad.ru/terms",
                "entitlements": {}
            }
            """.utf8
        )

        let config = try JSONDecoder().decode(ApplicationConfig.self, from: data)

        #expect(config.isServiceAvailable == ApplicationConfig.default.isServiceAvailable)
        #expect(config.locale.defaultCode == "en")
        #expect(config.locale.codes == ["en", "ru"])
        #expect(config.actualVersion.major == Version.default.major)
        #expect(config.legalDate == ApplicationConfig.default.legalDate)
        #expect(config.network.timeoutIntervalForResource == NetworkConfig.default.timeoutIntervalForResource)
        #expect(config.history.pageSize == HistoryConfig.default.pageSize)
        #expect(config.ultrasound.scanPhotoMaxNumber == UltrasoundConfig.default.scanPhotoMaxNumber)
    }

    @Test
    func applicationConfigRequiresLocale() {
        let data = Data(
            """
            {
                "appStoreId": "test",
                "contactEmail": "test@doglyad.ru",
                "appleUpdateUrl": "https://apps.apple.com/app/id",
                "privacyPolicyUrl": "https://doglyad.ru/privacy",
                "termsAndConditionsUrl": "https://doglyad.ru/terms",
                "entitlements": {}
            }
            """.utf8
        )

        #expect((try? JSONDecoder().decode(ApplicationConfig.self, from: data)) == nil)
    }

    @Test
    func languageUsesConfigAndPreferredLanguageOrder() {
        let locale = LocaleConfig(defaultCode: "en", codes: ["ru", "en"])
        let language = Language(
            localeConfig: locale,
            preferredLanguageIdentifiers: ["fr-FR", "ru-RU", "en-US"]
        )
        let fallback = Language(
            localeConfig: locale,
            preferredLanguageIdentifiers: ["fr-FR", "de-DE"]
        )

        #expect(language.currentCode == "ru")
        #expect(language.currentLocale.language.languageCode?.identifier == "ru")
        #expect(fallback.currentCode == "en")
    }

    @Test
    func examinationTypesDecodeLocalizedSpeechTerms() throws {
        let data = Data(
            """
            [{"id":"abdominalAndUrinarySystem","title":"Брюшная полость","examinationTypes":[
              {"id":"bladder","title":"Мочевой пузырь","contextualStrings":["остаточная моча"]},
              {"id":"abdominalCavity","title":"Брюшная полость","contextualStrings":["печень"]}
            ]}]
            """.utf8
        )
        let groups = try JSONDecoder().decode([USExaminationTypeGroup].self, from: data)

        #expect(groups[0].title == "Брюшная полость")
        #expect(groups[0].examinationTypes[0].contextualStrings == ["остаточная моча"])
        #expect(groups[0].examinationTypes[1].contextualStrings == ["печень"])
    }

    @Test
    func oldMultilingualResponseDoesNotSilentlyDecode() {
        let old = Data(
            """
            [{"id":"abdominalAndUrinarySystem","title":{"ru":"Брюшная полость"},
              "examinationTypes":[{"id":"bladder","title":{"ru":"Мочевой пузырь"}}]}]
            """.utf8
        )

        #expect((try? JSONDecoder().decode([USExaminationTypeGroup].self, from: old)) == nil)
    }

    @Test
    func localizedModelTemplateAndPromptDecodeAsStrings() throws {
        let model = try JSONDecoder().decode(
            USExaminationNeuralModel.self,
            from: Data(
                """
                {"id":"model","title":"Model","entitlement":"base","accessibility":"available",
                 "contextLength":128000,"description":"Описание модели"}
                """.utf8
            )
        )
        let template = try JSONDecoder().decode(
            USExaminationReadyMadeTemplate.self,
            from: Data(
                """
                {"id":"template","examinationType":"bladder","title":"Шаблон","content":"Описание"}
                """.utf8
            )
        )
        let config = try JSONDecoder().decode(
            UltrasoundExaminationNeuralModelConfig.self,
            from: Data(
                """
                {"temperature":0,"maxTokens":100,"maxContextTokens":200,"prompt":"Системный промпт"}
                """.utf8
            )
        )

        #expect(model.description == "Описание модели")
        #expect(template.title == "Шаблон")
        #expect(template.content == "Описание")
        #expect(config.prompt == "Системный промпт")
        #expect(config.proposalPrompt.isEmpty)
    }
}
