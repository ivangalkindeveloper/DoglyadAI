import Foundation

enum DExaminationProposalGenerationConfig {
    static let responseJSONSchema: String = #"""
    {
        "type": "object",
        "properties": {
            "proposals": {
                "type": "array",
                "maxItems": 8,
                "items": {
                    "type": "object",
                    "properties": {
                        "fieldId": {
                            "enum": [
                                "examinationNumber", "patientName", "patientGender",
                                "patientDateOfBirth", "patientHeightCM", "patientWeightKG",
                                "patientComplaints", "examinationDescription"
                            ]
                        },
                        "value": {"type": "string", "minLength": 1},
                        "sourceQuote": {"type": "string", "minLength": 1}
                    },
                    "required": ["fieldId", "value", "sourceQuote"],
                    "additionalProperties": false
                }
            },
            "unmappedFindings": {
                "type": "array",
                "items": {"type": "string"}
            }
        },
        "required": ["proposals", "unmappedFindings"],
        "additionalProperties": false
    }
    """#

    static func userPrompt(for request: DictationParseRequest) -> String {
        let fields = request.allowedFields.map(\.rawValue).joined(separator: ", ")
        let locale = request.locale.identifier(.bcp47)
        return """
        <examinationTypeId>\(request.examinationTypeId)</examinationTypeId>
        <locale>\(locale)</locale>
        <allowedFields>\(fields)</allowedFields>
        <dictation>
        \(request.text)
        </dictation>
        """
    }
}
