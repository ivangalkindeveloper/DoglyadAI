import Foundation

/// Spoken labels that explicitly bind an identifier to the examination.
enum DictationIdentifierCue {
    static let pattern = #"(?:"#
        + #"this\s+is\s+study|study|examination\s+number|examination|scan\s+number|"#
        + #"file\s+reference|record\s+(?:carries\s+number|marked)|filed\s+as\s+study|"#
        + #"(?:today.s\s+)?scan\s+is\s+numbered|(?:the\s+)?(?:registration|reference|visit|case|protocol)\s+number(?:\s+is|\s+was)?|"#
        + #"case|protocol|^number|"#
        + #"это\s+исследование\s+номер|номер\s+исследования|в\s+исследовании|исследование|"#
        + #"обследование\s+номер|протокол\s+под\s+номером|по\s+протоколу|"#
        + #"зарегистрировано\s+за\s+номером|оформлена\s+под\s+номером|"#
        + #"(?:случай|карточка)\s+номер|регистрационный\s+номер|"#
        + #"номер\s+(?:обследования|визита|протокола|случая)|"#
        + #"сегодняшнему\s+исследованию\s+присвоен\s+номер|протокол|^номер)"#
}
