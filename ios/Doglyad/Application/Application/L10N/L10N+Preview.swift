import DoglyadNeuralModel
import Foundation

extension L10N {
    /// Previews display technical keys; production translations are never bundled.
    static func previewable(
        code: String,
    ) -> L10N {
        let emptyPattern = "(?!)"
        let voice: [String: Any] = [
            "code": code,
            "dictation": [
                "patterns": Dictionary(
                    uniqueKeysWithValues: DNeuralUltrasoundDictationLocalizationKey.allCases.map { ($0.rawValue, emptyPattern) },
                ),
                "namePatterns": [],
                "genderPatterns": [],
                "numbers": ["ones": Array(
                    repeating: "",
                    count: 20,
                ), "tens": Array(
                    repeating: "",
                    count: 10,
                ), "hundred": "__preview__", "digits": ["0": "0"]],
                "negativeCorrectionWord": "__preview__",
                "usesDayFirstNumericDates": true,
                "birthEvidenceUsesValue": false,
                "dateFormats": ["yyyy-MM-dd"],
                "shortUnits": ["millimeter": "__preview__", "velocity": "__preview__", "milliliter": "__preview__"],
                "schema": Dictionary(
                    uniqueKeysWithValues: ["patientName", "patientGender", "patientDateOfBirth", "patientHeightCM", "patientWeightKG", "patientComplaints", "examinationDescription", "fieldId", "value", "evidence", "accuracy"].map { ($0, $0) },
                ),
            ],
            "speech": [
                "negationPattern": emptyPattern,
                "leftSidePattern": emptyPattern,
                "rightSidePattern": emptyPattern,
                "literalCharacterReplacements": [:],
                "phoneticCharacterReplacements": [:],
                "ignoredPhoneticCharacters": "",
            ],
        ]
        let payload: [String: Any] = [
            "code": code,
            "strings": Dictionary(
                uniqueKeysWithValues: L10NKey.allCases.map { ($0.rawValue, $0.rawValue) },
            ),
            "voice": voice,
        ]
        let data = try! JSONSerialization.data(
            withJSONObject: payload,
        )
        let localization = try! JSONDecoder().decode(
            Localization.self,
            from: data,
        )
        return try! L10N(
            localization: localization,
        )
    }
}
