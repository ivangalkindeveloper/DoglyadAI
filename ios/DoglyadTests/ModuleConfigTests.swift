@testable import Doglyad
import Foundation
import Testing

struct ModuleConfigTests {
    @Test(
        arguments: ["scan", "scanSpeech", "templateAdd", "templateEdit", "readyMadeTemplateList", "workSettings", "settingsAI"],
    )
    func moduleSectionsAreRequired(
        section: String,
    ) throws {
        var document = try configurationDocument()
        document.removeValue(
            forKey: section,
        )
        let data = try JSONSerialization.data(
            withJSONObject: document,
        )
        #expect(
            throws: DecodingError.self,
        ) {
            try JSONDecoder().decode(
                ApplicationConfig.self,
                from: data,
            )
        }
    }

    @Test(
        arguments: [0, -1],
    )
    func nonPositiveLimitsAreRejected(
        maximum: Int,
    ) throws {
        var document = try configurationDocument()
        var scan = try #require(
            document[
                "scan",
            ] as? [String: Any],
        )
        scan[
            "patientNameMaxLength",
        ] = maximum
        document[
            "scan",
        ] = scan
        let data = try JSONSerialization.data(
            withJSONObject: document,
        )
        #expect(
            throws: DecodingError.self,
        ) {
            try JSONDecoder().decode(
                ApplicationConfig.self,
                from: data,
            )
        }
    }

    @Test
    func moduleLimitsDecodeIndependentlyWithoutLocalDefaults() throws {
        var document = try configurationDocument()
        document[
            "templateAdd",
        ] = ["nameMaxLength": 30, "contentMaxLength": 300]
        document[
            "templateEdit",
        ] = ["nameMaxLength": 50, "contentMaxLength": 500]
        let data = try JSONSerialization.data(
            withJSONObject: document,
        )
        let config = try JSONDecoder().decode(
            ApplicationConfig.self,
            from: data,
        )
        #expect(
            config.templateAdd.nameMaxLength == 30,
        )
        #expect(
            config.templateEdit.nameMaxLength == 50,
        )
        #expect(
            config.templateAdd.contentMaxLength == 300,
        )
        #expect(
            config.templateEdit.contentMaxLength == 500,
        )
    }

    @Test
    func unusedHeightAndWeightDefaultsAreNotEncoded() throws {
        let data = try JSONEncoder().encode(
            UltrasoundConfig.default,
        )
        let document = try #require(
            JSONSerialization.jsonObject(
                with: data,
            ) as? [String: Any],
        )
        #expect(
            document[
                "defaultPatientHeightCM",
            ] == nil,
        )
        #expect(
            document[
                "defaultPatientWeightKG",
            ] == nil,
        )
    }

    private func configurationDocument() throws -> [String: Any] {
        let data = try JSONEncoder().encode(
            ApplicationConfig.default,
        )
        return try #require(
            JSONSerialization.jsonObject(
                with: data,
            ) as? [String: Any],
        )
    }
}
