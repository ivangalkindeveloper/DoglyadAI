import Foundation

enum DExaminationProposalGenerationConfig {
    static let responseJSONSchema: String = #"""
    {
        "type": "array",
        "maxItems": 8,
        "items": {
            "type": "object",
            "properties": {
                "field_id": {
                    "enum": [
                        "examination_number", "patient_name", "patient_gender",
                        "patient_date_of_birth", "patient_height_cm", "patient_weight_kg",
                        "patient_complaints", "examination_description"
                    ]
                },
                "value": {"type": ["string", "number"]},
                "evidence": {"type": "string", "minLength": 1},
                "accuracy": {"enum": ["full", "questionable"]}
            },
            "required": ["field_id", "value", "evidence", "accuracy"],
            "additionalProperties": false
        }
    }
    """#

    static func userPrompt(for request: DictationParseRequest) -> String {
        let fields = request.allowedFields.map(\.wireValue).joined(separator: ", ")
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
