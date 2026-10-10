import Foundation

public struct DNeuralUltrasoundDictationParseRequest: Sendable {
    public let text: String
    public let examinationTypeId: String
    public let examinationTypeTitle: String
    public let locale: Locale
    public let allowedFields: [DNeuralUltrasoundVoiceFieldId]
    public let localization: DNeuralUltrasoundDictationLocalization

    public init(
        text: String,
        examinationTypeId: String,
        examinationTypeTitle: String,
        locale: Locale,
        allowedFields: [DNeuralUltrasoundVoiceFieldId],
        localization: DNeuralUltrasoundDictationLocalization,
    ) {
        self.text = text
        self.examinationTypeId = examinationTypeId
        self.examinationTypeTitle = examinationTypeTitle
        self.locale = locale
        self.allowedFields = allowedFields
        self.localization = localization
    }
}
