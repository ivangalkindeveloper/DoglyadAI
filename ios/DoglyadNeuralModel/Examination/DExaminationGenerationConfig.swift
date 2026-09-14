import Foundation

class DExaminationGenerationConfig {
    static let dateFormat: String = "yyyy-MM-dd"
    static let promptDateFormat: String = "YYYY-MM-DD"
    static let responseJSONSchema: String = #"""
    {
        "type": "object",
        "properties": {
            "patientName": {
                "type": ["string", "null"],
                "minLength": 1
            },
            "patientGender": {
                "enum": ["male", "female", null]
            },
            "patientDateOfBirth": {
                "anyOf": [
                    {
                        "type": "string",
                        "pattern": "^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$"
                    },
                    {
                        "type": "null"
                    }
                ]
            },
            "patientHeightCM": {
                "type": ["number", "null"]
            },
            "patientWeightKG": {
                "type": ["number", "null"]
            },
            "patientComplaints": {
                "type": ["string", "null"],
                "minLength": 1
            },
            "examinationDescription": {
                "type": ["string", "null"],
                "minLength": 1
            }
        },
        "required": [
            "patientName",
            "patientGender",
            "patientDateOfBirth",
            "patientHeightCM",
            "patientWeightKG",
            "patientComplaints",
            "examinationDescription"
        ],
        "additionalProperties": false
    }
    """#
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.calendar = Calendar(identifier: .gregorian)
        return formatter
    }()

    static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
        return decoder
    }()

    static func userPrompt(
        for dictation: String
    ) -> String {
        """
        <dictation>
        \(dictation)
        </dictation>
        """
    }
}
