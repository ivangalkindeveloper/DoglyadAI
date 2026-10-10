import DoglyadNeuralModel
import Foundation
import FoundationModels

/// Historical nullable-contract baseline, excluded from the application framework.
@available(iOS 26.0, *)
final class DNeuralUltrasoundLegacyModelFoundationModels {
    @FoundationModels.Generable
    struct DNeuralUltrasoundResponse {
        let patientName: String?

        let patientGender: DNeuralUltrasoundGender?

        let patientDateOfBirth: String?

        let patientHeightCM: Double?

        let patientWeightKG: Double?

        let patientComplaints: String?

        let examinationDescription: String?

        static func schema(
            localization: DNeuralUltrasoundSchemaLocalization,
        ) -> GenerationSchema {
            GenerationSchema(
                type: Self.self,
                properties: [
                    .init(
                        name: "patientName",
                        description: localization.patientName,
                        type: String?.self,
                    ),
                    .init(
                        name: "patientGender",
                        description: localization.patientGender,
                        type: DNeuralUltrasoundGender?.self,
                    ),
                    .init(
                        name: "patientDateOfBirth",
                        description: localization.patientDateOfBirth,
                        type: String?.self,
                    ),
                    .init(
                        name: "patientHeightCM",
                        description: localization.patientHeightCM,
                        type: Double?.self,
                    ),
                    .init(
                        name: "patientWeightKG",
                        description: localization.patientWeightKG,
                        type: Double?.self,
                    ),
                    .init(
                        name: "patientComplaints",
                        description: localization.patientComplaints,
                        type: String?.self,
                    ),
                    .init(
                        name: "examinationDescription",
                        description: localization.examinationDescription,
                        type: String?.self,
                    ),
                ],
            )
        }
    }

    @FoundationModels.Generable
    enum DNeuralUltrasoundGender {
        case male
        case female
    }

    private let systemPrompt: String
    private let localization: DNeuralUltrasoundSchemaLocalization
    private let options: GenerationOptions

    init(
        systemPrompt: String,
        parameters: DNeuralGenerationParameters,
        localization: DNeuralUltrasoundSchemaLocalization,
    ) {
        self.systemPrompt = systemPrompt
        self.localization = localization
        options = GenerationOptions(
            temperature: parameters.temperature,
            maximumResponseTokens: parameters.maxTokens,
        )
    }

    func parseSpeech(
        speech: String,
    ) async throws -> DNeuralUltrasoundLegacyResponse {
        let session = LanguageModelSession(
            instructions: systemPrompt,
        )
        let response = try await session.respond(
            to: DNeuralUltrasoundLegacyGenerationConfig.userPrompt(
                for: speech,
            ),
            schema: DNeuralUltrasoundResponse.schema(
                localization: localization,
            ),
            options: options,
        )
        return try DNeuralUltrasoundLegacyResponse.fromFoudationModels(
            DNeuralUltrasoundResponse(
                response.content,
            ),
        )
    }
}
