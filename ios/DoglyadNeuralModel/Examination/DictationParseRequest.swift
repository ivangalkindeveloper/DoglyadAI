import Foundation

public struct DictationParseRequest: Sendable {
    public let text: String
    public let examinationTypeId: String
    public let locale: Locale
    public let allowedFields: [VoiceFieldId]

    public init(
        text: String,
        examinationTypeId: String,
        locale: Locale,
        allowedFields: [VoiceFieldId]
    ) {
        self.text = text
        self.examinationTypeId = examinationTypeId
        self.locale = locale
        self.allowedFields = allowedFields
    }
}
