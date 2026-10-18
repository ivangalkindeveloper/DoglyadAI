@testable import DoglyadNeuralModel
import Foundation
import Testing

struct DictationNormalizationTests {
    @Test(
        arguments: ["23 0 8 2014 год", "23 08 2014"],
    )
    func groupedDayFirstDateIsRecoveredFromTheActualSource(
        _ spoken: String,
    ) throws {
        let request = request(
            "Дата рождения: " + spoken,
            code: "ru",
        )
        let proposal = try DNeuralUltrasoundProposalProcessor(
            request: request,
        ).process(
            generated: DNeuralUltrasoundProposalGenerationResponse(
                proposals: [],
            ),
            source: .serverModel,
        )
        let field = try #require(
            proposal.proposals.first { $0.id.isPatientDateOfBirth },
        )
        guard case let .date(
            date,
        ) = field.value else { Issue.record(
            "Missing date",
        )
        return
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        #expect(
            formatter.string(
                from: date,
            ) == "2014-08-23",
        )
        #expect(
            request.text.contains(
                field.sourceQuote,
            ),
        )
    }

    @Test(
        arguments: ["29 0 2 2001", "23 0 2014", "9 23 0 8 2014"],
    )
    func incompleteOrInvalidDatesAreNotGuessed(
        _ spoken: String,
    ) {
        let request = request(
            "Дата рождения: " + spoken,
            code: "ru",
        )
        let result = DNeuralUltrasoundProposalProcessor(
            request: request,
        ).deterministic
        #expect(
            !result.proposals.contains { $0.id.isPatientDateOfBirth },
        )
    }

    @Test
    func finalNameNormalizationPreservesLettersAndOriginalQuote() throws {
        let request = request(
            "Пациент: сидорова анна львовна",
            code: "ru",
        )
        let result = DNeuralUltrasoundProposalProcessor(
            request: request,
        ).deterministic
        let field = try #require(
            result.proposals.first,
        )
        #expect(
            field.value == .text(
                "Сидорова Анна Львовна",
            ),
        )
        #expect(
            request.text.contains(
                field.sourceQuote,
            ),
        )
        #expect(
            DNeuralVoiceFieldValue.normalizedPatientName(
                "John McDonald O'NEILL",
                locale: Locale(
                    identifier: "en",
                ),
            ) == "John McDonald O'Neill",
        )
    }

    @Test
    func formattingSurvivesReconciliationWithoutChangingTheQuotedText() throws {
        let raw = "стенка 2,7 мм объём 180 мл включений нет"
        let formatted = "Стенка 2,7 мм. Объём 180 мл. Включений нет."
        let request = request(
            "Описание исследования: " + raw,
            code: "ru",
        )
        let result = try DNeuralUltrasoundProposalProcessor(
            request: request,
        ).process(
            generated: DNeuralUltrasoundProposalGenerationResponse(
                proposals: [DNeuralUltrasoundProposalGenerationItem(
                    fieldId: .examinationDescription,
                    value: formatted,
                    sourceQuote: raw,
                    accuracy: .full,
                )],
            ),
            source: .serverModel,
        )
        let field = try #require(
            result.proposals.first { $0.id.isExaminationDescription },
        )
        #expect(
            field.value == .text(
                formatted,
            ),
        )
        #expect(
            request.text.contains(
                field.sourceQuote,
            ),
        )
        #expect(
            field.warnings.isEmpty,
        )
    }

    @Test(
        arguments: [
            "Стенка 2,8 мм. Объём 180 мл. Включений нет.",
            "Стенка 2,7 мм. Объём 180 мл.",
            "Стенка 2,7 мм. Объём 180 мл. Включения есть.",
            "Стенка 2,7 см. Объём 180 мл. Включений нет.",
        ],
    )
    func changedClinicalContentIsRetainedForReview(
        _ formatted: String,
    ) throws {
        let raw = "стенка 2,7 мм объём 180 мл включений нет"
        let request = request(
            "Описание исследования: " + raw,
            code: "ru",
        )
        let result = try DNeuralUltrasoundProposalProcessor(
            request: request,
        ).process(
            generated: DNeuralUltrasoundProposalGenerationResponse(
                proposals: [DNeuralUltrasoundProposalGenerationItem(
                    fieldId: .examinationDescription,
                    value: formatted,
                    sourceQuote: raw,
                    accuracy: .full,
                )],
            ),
            source: .serverModel,
        )
        #expect(
            result.proposals.first { $0.id.isExaminationDescription }?.value == .text(
                formatted,
            ),
        )
    }

    @Test(
        arguments: [
            ("ru", "содержимое анофагенное", "Содержимое анэхогенное.", "Описание исследования: "),
            ("en", "anechoeic contents", "Anechoic contents.", "Examination description: "),
        ],
    )
    func contextualTermCorrectionSurvivesSourceReconciliationForReview(
        _ code: String,
        _ raw: String,
        _ corrected: String,
        _ label: String,
    ) throws {
        let request = request(
            label + raw,
            code: code,
        )
        let result = try DNeuralUltrasoundProposalProcessor(
            request: request,
        ).process(
            generated: DNeuralUltrasoundProposalGenerationResponse(
                proposals: [DNeuralUltrasoundProposalGenerationItem(
                    fieldId: .examinationDescription,
                    value: corrected,
                    sourceQuote: raw,
                    accuracy: .full,
                )],
            ),
            source: .serverModel,
        )
        let field = try #require(
            result.proposals.first { $0.id.isExaminationDescription },
        )
        #expect(
            field.value == .text(
                corrected,
            ),
        )
        #expect(
            field.accuracy == .questionable,
        )
        #expect(
            field.warnings.contains(
                .textChanged,
            ),
        )
        #expect(
            request.text.contains(
                field.sourceQuote,
            ),
        )
        #expect(
            field.sourceQuote.contains(
                raw,
            ),
        )
    }

    @Test(
        arguments: [
            "Содержимое анэхогенное справа. Стенка 2,3 мм. Включений нет.",
            "Содержимое анэхогенное слева. Стенка 2,4 мм. Включений нет.",
            "Содержимое анэхогенное слева. Стенка 2,3 см. Включений нет.",
            "Содержимое анэхогенное слева. Стенка 2,3 мм. Включения есть.",
            "Содержимое анэхогенное слева. Стенка 2,3 мм.",
            "Содержимое анэхогенное слева. Включений нет. Стенка 2,3 мм.",
            "Содержимое анэхогенное слева. Стенка 2,3 мм. Включений нет. Контуры ровные.",
            "Содержимое гипоэхогенное слева. Стенка 2,3 мм. Включений нет.",
        ],
    )
    func clinicalDifferencesRetainTheModelValueForReview(
        _ corrected: String,
    ) throws {
        let raw = "содержимое анофагенное слева стенка 2,3 мм включений нет"
        let request = request(
            "Описание исследования: " + raw,
            code: "ru",
        )
        let result = try DNeuralUltrasoundProposalProcessor(
            request: request,
        ).process(
            generated: DNeuralUltrasoundProposalGenerationResponse(
                proposals: [DNeuralUltrasoundProposalGenerationItem(
                    fieldId: .examinationDescription,
                    value: corrected,
                    sourceQuote: raw,
                    accuracy: .full,
                )],
            ),
            source: .serverModel,
        )
        #expect(
            result.proposals.first { $0.id.isExaminationDescription }?.value == .text(
                corrected,
            ),
        )
    }

    @Test(
        arguments: ["эхагенная взвесь", "эхагинная взвесь"],
    )
    func unknownRecognitionErrorsRemainReviewableWithoutCorrectionPairs(
        _ raw: String,
    ) throws {
        let request = request(
            "Описание исследования: " + raw,
            code: "ru",
        )
        let result = try DNeuralUltrasoundProposalProcessor(
            request: request,
        ).process(
            generated: DNeuralUltrasoundProposalGenerationResponse(
                proposals: [DNeuralUltrasoundProposalGenerationItem(
                    fieldId: .examinationDescription,
                    value: "Эхогенная взвесь.",
                    sourceQuote: raw,
                    accuracy: .full,
                )],
            ),
            source: .serverModel,
        )
        let field = try #require(
            result.proposals.first { $0.id.isExaminationDescription },
        )
        #expect(
            field.value == .text(
                "Эхогенная взвесь.",
            ),
        )
        #expect(
            field.sourceQuote == raw,
        )
        #expect(
            field.accuracy == .questionable,
        )
        #expect(
            field.warnings.contains(
                .textChanged,
            ),
        )
    }

    @Test
    func aModelDenialThatContradictsTheComplaintIsRetainedForReview() throws {
        let raw = "боль слева"
        let request = request(
            "Жалобы: " + raw,
            code: "ru",
        )
        let result = try DNeuralUltrasoundProposalProcessor(
            request: request,
        ).process(
            generated: DNeuralUltrasoundProposalGenerationResponse(
                proposals: [DNeuralUltrasoundProposalGenerationItem(
                    fieldId: .patientComplaints,
                    value: "Жалоб нет.",
                    sourceQuote: raw,
                    accuracy: .full,
                )],
            ),
            source: .serverModel,
        )
        let field = try #require(
            result.proposals.first { $0.id == .patientComplaints },
        )
        #expect(
            field.value == .text(
                "Жалоб нет.",
            ),
        )
        #expect(
            field.sourceQuote == raw,
        )
        #expect(
            field.accuracy == .questionable,
        )
        #expect(
            field.warnings.contains(
                .textChanged,
            ),
        )
        #expect(
            field.warnings.contains(
                .negationMismatch,
            ),
        )
    }

    private func request(
        _ text: String,
        code: String,
    ) -> DNeuralUltrasoundDictationParseRequest {
        let locale = Locale(
            identifier: code,
        )
        return DNeuralUltrasoundDictationParseRequest(
            text: text,
            examinationTypeId: "bladder",
            examinationTypeTitle: "Unit-test examination",
            locale: locale,
            allowedFields: DNeuralUltrasoundVoiceFieldId.allCases,
            localization: VoiceLocalizationTestSupport.dictation(
                locale: locale,
            ),
        )
    }
}
