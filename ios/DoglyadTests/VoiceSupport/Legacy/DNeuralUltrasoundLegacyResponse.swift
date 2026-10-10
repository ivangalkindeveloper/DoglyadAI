import Foundation

public struct DNeuralUltrasoundLegacyResponse: Codable {
    public enum DNeuralUltrasoundGender: String, Codable {
        case male
        case female

        @available(iOS 26.0, *)
        static func fromFoudationModels(
            _ response: DNeuralUltrasoundLegacyModelFoundationModels.DNeuralUltrasoundGender?,
        ) -> Self? {
            switch response {
            case .male:
                .male
            case .female:
                .female
            case nil:
                nil
            }
        }
    }

    public let patientName: String?
    public let patientGender: DNeuralUltrasoundGender?
    public let patientDateOfBirth: Date?
    public let patientHeightCM: Double?
    public let patientWeightKG: Double?
    public let patientComplaints: String?
    public let examinationDescription: String?

    public init(
        from decoder: any Decoder,
    ) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self,
        )

        patientName = try container.decodeIfPresent(
            String.self,
            forKey: .patientName,
        )
        patientGender = try container.decodeIfPresent(
            DNeuralUltrasoundGender.self,
            forKey: .patientGender,
        )
        patientDateOfBirth = try DNeuralUltrasoundLegacyGenerationConfig.dateFormatter.date(
            from: container.decodeIfPresent(
                String.self,
                forKey: .patientDateOfBirth,
            ) ?? "",
        )
        patientHeightCM = try container.decodeIfPresent(
            Double.self,
            forKey: .patientHeightCM,
        )
        patientWeightKG = try container.decodeIfPresent(
            Double.self,
            forKey: .patientWeightKG,
        )
        patientComplaints = try container.decodeIfPresent(
            String.self,
            forKey: .patientComplaints,
        )
        examinationDescription = try container.decodeIfPresent(
            String.self,
            forKey: .examinationDescription,
        )
    }

    init(
        patientName: String?,
        patientGender: DNeuralUltrasoundGender?,
        patientDateOfBirth: Date?,
        patientHeightCM: Double?,
        patientWeightKG: Double?,
        patientComplaints: String?,
        examinationDescription: String?,
    ) {
        self.patientName = patientName
        self.patientGender = patientGender
        self.patientDateOfBirth = patientDateOfBirth
        self.patientHeightCM = patientHeightCM
        self.patientWeightKG = patientWeightKG
        self.patientComplaints = patientComplaints
        self.examinationDescription = examinationDescription
    }

    @available(iOS 26.0, *)
    static func fromFoudationModels(
        _ response: DNeuralUltrasoundLegacyModelFoundationModels.DNeuralUltrasoundResponse,
    ) -> Self {
        DNeuralUltrasoundLegacyResponse(
            patientName: response.patientName,
            patientGender: DNeuralUltrasoundGender.fromFoudationModels(
                response.patientGender,
            ),
            patientDateOfBirth: DNeuralUltrasoundLegacyGenerationConfig.dateFormatter.date(
                from: response.patientDateOfBirth ?? "",
            ),
            patientHeightCM: response.patientHeightCM,
            patientWeightKG: response.patientWeightKG,
            patientComplaints: response.patientComplaints,
            examinationDescription: response.examinationDescription,
        )
    }
}
