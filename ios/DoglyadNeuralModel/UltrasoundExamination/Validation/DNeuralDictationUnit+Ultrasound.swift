import Foundation

extension DNeuralDictationUnit {
    static func fromWord(
        _ word: String,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> Self? {
        allCases.first { unit in
            let key: DNeuralUltrasoundDictationLocalizationKey = switch unit {
            case .millimeter: .unitMillimeter
            case .centimeter: .unitCentimeter
            case .meter: .unitMeter
            case .gram: .unitGram
            case .kilogram: .unitKilogram
            case .milliliter: .unitMilliliter
            case .liter: .unitLiter
            case .percent: .unitPercent
            }
            return localization.matches(
                key,
                word,
            )
        }
    }
}
