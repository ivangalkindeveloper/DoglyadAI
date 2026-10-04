import Foundation

struct DExaminationProposalGenerationItem: Codable {
    let fieldId: VoiceFieldId
    let value: String
    let sourceQuote: String
    let accuracy: VoiceFieldAccuracy

    init(
        fieldId: VoiceFieldId, value: String, sourceQuote: String,
        accuracy: VoiceFieldAccuracy = .full
    ) {
        self.fieldId = fieldId
        self.value = value
        self.sourceQuote = sourceQuote
        self.accuracy = accuracy
    }

    private enum CodingKeys: String, CodingKey {
        case fieldId = "field_id"
        case value
        case sourceQuote = "evidence"
        case accuracy
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let wireId = try container.decode(String.self, forKey: .fieldId)
        guard let fieldId = VoiceFieldId(wireValue: wireId) else {
            throw DecodingError.dataCorruptedError(forKey: .fieldId, in: container, debugDescription: "Unknown field ID")
        }
        self.fieldId = fieldId
        switch fieldId {
        case .patientHeightCM, .patientWeightKG:
            if let number = try? container.decode(Double.self, forKey: .value) {
                value = String(number)
            } else {
                value = try container.decode(String.self, forKey: .value)
            }
        case .examinationNumber, .patientName, .patientGender, .patientDateOfBirth,
             .patientComplaints, .examinationDescription:
            value = try container.decode(String.self, forKey: .value)
        }
        sourceQuote = try container.decode(String.self, forKey: .sourceQuote)
        accuracy = try container.decode(VoiceFieldAccuracy.self, forKey: .accuracy)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fieldId.wireValue, forKey: .fieldId)
        switch fieldId {
        case .patientHeightCM, .patientWeightKG:
            guard let number = Double(value), number.isFinite else {
                throw EncodingError.invalidValue(value, .init(codingPath: encoder.codingPath, debugDescription: "Invalid measurement"))
            }
            try container.encode(number, forKey: .value)
        case .examinationNumber, .patientName, .patientGender, .patientDateOfBirth,
             .patientComplaints, .examinationDescription:
            try container.encode(value, forKey: .value)
        }
        try container.encode(sourceQuote, forKey: .sourceQuote)
        try container.encode(accuracy, forKey: .accuracy)
    }
}
