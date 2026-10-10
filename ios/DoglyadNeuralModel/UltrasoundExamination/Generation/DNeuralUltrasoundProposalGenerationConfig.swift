import Foundation

enum DNeuralUltrasoundProposalGenerationConfig {
    static func userPrompt(
        for request: DNeuralUltrasoundDictationParseRequest,
    ) -> String {
        let fields = request.allowedFields.map(
            \.wireValue,
        ).joined(
            separator: ", ",
        )
        let locale = request.locale.identifier(
            .bcp47,
        )
        return """
        <examinationType>\(request.examinationTypeTitle)</examinationType>
        <locale>\(locale)</locale>
        <allowedFields>\(fields)</allowedFields>
        <dictation>
        \(request.text)
        </dictation>
        """
    }
}
