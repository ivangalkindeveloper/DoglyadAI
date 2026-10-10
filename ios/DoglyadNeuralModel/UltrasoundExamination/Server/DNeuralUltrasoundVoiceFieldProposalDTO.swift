import Foundation

public struct DNeuralUltrasoundVoiceFieldProposalDTO: Decodable, Sendable {
    public let fieldId: DNeuralUltrasoundVoiceFieldId
    public let value: String
    public let sourceQuote: String
    public let accuracy: DNeuralVoiceFieldAccuracy

    private enum DNeuralUltrasoundCodingKeys: String, CodingKey {
        case fieldId = "field_id"
        case value
        case sourceQuote = "evidence"
        case accuracy
    }

    public init(
        from decoder: Decoder,
    ) throws {
        let container = try decoder.container(
            keyedBy: DNeuralUltrasoundCodingKeys.self,
        )
        let wireId = try container.decode(
            String.self,
            forKey: .fieldId,
        )
        guard let fieldId = DNeuralUltrasoundVoiceFieldId(
            wireValue: wireId,
        ) else {
            throw DecodingError.dataCorruptedError(
                forKey: .fieldId,
                in: container,
                debugDescription: "Unknown field ID",
            )
        }
        self.fieldId = fieldId
        switch fieldId {
        case .patientHeightCM, .patientWeightKG:
            value = try String(
                container.decode(
                    Double.self,
                    forKey: .value,
                ),
            )
        case .examinationNumber, .patientName, .patientGender, .patientDateOfBirth,
             .patientComplaints, .examinationDescription:
            value = try container.decode(
                String.self,
                forKey: .value,
            )
        }
        sourceQuote = try container.decode(
            String.self,
            forKey: .sourceQuote,
        )
        accuracy = try container.decode(
            DNeuralVoiceFieldAccuracy.self,
            forKey: .accuracy,
        )
    }
}
