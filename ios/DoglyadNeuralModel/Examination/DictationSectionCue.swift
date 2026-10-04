import Foundation

/// Explicit transitions between complaints, body measurements, and findings.
enum DictationSectionCue {
    static let complaint = #"(?:"#
        + #"they\s+report|they\s+complain\s+of|the\s+(?:patient\s+)?complaint\s+is|"#
        + #"the\s+concern\s+is|the\s+presenting\s+concern\s+is|"#
        + #"the\s+patient\s+(?:mentions|describes|reports|complains\s+of)|"#
        + #"the\s+reason\s+for\s+this\s+visit\s+is|"#
        + #"the\s+(?:chief\s+complaint|reported\s+problem|symptom\s+described)\s+(?:is|was)|"#
        + #"(?:the\s+)?(?:reason\s+for\s+(?:examination|the\s+scan)|symptoms|indication)\s*(?:are|is)?|"#
        + #"сообщает(?:\s+о)?|жалобы|из\s+жалоб|жалуется\s+на|беспокоит|беспокоят|"#
        + #"пациент\s+(?:отмечает|жалуется\s+на)|повод\s+(?:для\s+обращения|обследования)|"#
        + #"причина\s+(?:визита|исследования)|со\s+слов\s+пациента|"#
        + #"основная\s+жалоба|из\s+симптомов|повод\s+обращения)"#

    static let measurement = #"(?:"#
        + #"and\s+weigh|(?:body|measured)\s+weight|their\s+measured\s+weight|"#
        + #"(?:the\s+patient|they)\s+weigh|weight\s+(?:is|comes\s+to|recorded\s+at)|"#
        + #"measured\s+height|height\s+(?:is|comes\s+to)|"#
        + #"масса\s+(?:тела|пациента)|измеренная\s+масса\s+тела|текущий\s+вес|"#
        + #"вес(?:ит|\s+пациента|\s+(?:равен|составляет))?|измеренный\s+вес|"#
        + #"рост\s+(?:равен|составляет))"#
}
