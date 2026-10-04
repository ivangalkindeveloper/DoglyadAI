import Foundation

/// Phrases that explicitly introduce ultrasound findings in a transcript.
/// The same boundary is used when extracting a finding and when checking that
/// a model quote has not omitted part of it.
enum DictationObservationCue {
    static let pattern = #"(?:"#
        + #"(?:on|an)\s+ultrasound|ultrasound\s+(?:findings\s+are|demonstrates|assessment)|"#
        + #"(?:the\s+)?scan\s+(?:shows|documented|found)|(?:the\s+)?images\s+show|"#
        + #"(?:the\s+)?sonographic\s+(?:findings|observations|examination\s+showed)|"#
        + #"on\s+(?:the\s+)?sonogram\s+i\s+see|"#
        + #"sonography\s+(?:shows|documented)|(?:the\s+)?sonogram\s+describes|"#
        + #"(?:the\s+)?ultrasound\s+examination\s+found|imaging\s+(?:revealed|assessment)|on\s+imaging|"#
        + #"\bна\s*узз?[аэе]?\s*(?:и|[яй](?:\s+и)?)\b|по\s+ультразвуку|эхографически|"#
        + #"ультразвуковая\s+картина(?:\s+(?:следующая|показывает))?|"#
        + #"при\s+сонографии\s+отмечено|ультразвуковое\s+исследование\s+показало|"#
        + #"сонография\s+показала|при\s+визуализации\s+отмечено|"#
        + #"ультразвук\s+выявил|при\s+уз[-\s]*исследовании\s+обнаружено|"#
        + #"на\s+снимках\s+видно|исследование\s+показало|на\s+эхограмме\s+видно|"#
        + #"при\s+ультразвуковом\s+осмотре\s+обнаружено)"#

    static func removeFraming(from text: String) -> String {
        text.replacingOccurrences(
            of: #"^\s*(?:"# + pattern + #"|узи)\s*[,.:—-]?\s*"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
    }
}
