@testable import Doglyad
import Foundation
import Testing

struct ConfigTests {
    @Test
    func defaultApplicationConfigRoundTrips() throws {
        let data = try JSONEncoder().encode(ApplicationConfig.default)
        let config = try JSONDecoder().decode(ApplicationConfig.self, from: data)

        #expect(config.actualVersion.major == Version.default.major)
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
        #expect(config.actualVersion.major == Version.default.major)
        #expect(config.legalDate == ApplicationConfig.default.legalDate)
        #expect(config.network.timeoutIntervalForResource == NetworkConfig.default.timeoutIntervalForResource)
        #expect(config.history.pageSize == HistoryConfig.default.pageSize)
        #expect(config.ultrasound.scanPhotoMaxNumber == UltrasoundConfig.default.scanPhotoMaxNumber)
    }
}
