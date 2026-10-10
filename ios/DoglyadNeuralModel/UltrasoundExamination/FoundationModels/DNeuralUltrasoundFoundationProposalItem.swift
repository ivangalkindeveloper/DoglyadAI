import FoundationModels

@available(iOS 26.0, *)
@FoundationModels.Generable
struct DNeuralUltrasoundFoundationProposalItem {
    let field_id: String

    let value: String

    let evidence: String

    let accuracy: String

    static func arraySchema(
        localization: DNeuralUltrasoundSchemaLocalization,
    ) throws -> GenerationSchema {
        let item = DynamicGenerationSchema(
            name: String(
                describing: Self.self,
            ),
            properties: [
                .init(
                    name: "field_id",
                    description: localization.fieldId,
                    schema: .init(
                        type: String.self,
                    ),
                ),
                .init(
                    name: "value",
                    description: localization.value,
                    schema: .init(
                        type: String.self,
                    ),
                ),
                .init(
                    name: "evidence",
                    description: localization.evidence,
                    schema: .init(
                        type: String.self,
                    ),
                ),
                .init(
                    name: "accuracy",
                    description: localization.accuracy,
                    schema: .init(
                        type: String.self,
                    ),
                ),
            ],
        )
        return try GenerationSchema(
            root: DynamicGenerationSchema(
                arrayOf: item,
            ),
            dependencies: [],
        )
    }
}
