@testable import DoglyadNeuralModel
import Foundation
import Testing

struct DictationClinicalSectionsTests {
    @Test(
        "Identity and absence of complaints cannot supply an ultrasound description",
    )
    func rejectsNonClinicalDescription() throws {
        for (quote, value) in [("Patient: Claire Wilson.", "Patient: Claire Wilson."), ("Complaints. No complaints.", "No complaints.")] {
            let result = try DNeuralUltrasoundProposalProcessor.validate(
                generated: .init(
                    proposals: [item(
                        .examinationDescription,
                        value,
                        quote,
                    )],
                ),
                request: request(
                    quote,
                ),
            )
            #expect(
                result.proposals.isEmpty,
            )
            #expect(
                !result.proposals.contains { $0.id == .examinationDescription },
            )
        }
    }

    @Test(
        "A short model complaint is preserved with a warning about the missing continuation",
    )
    func completesComplaint() throws {
        let text = "He complains of painful urination. No visible blood. Right kidney measures 110 mm. No calculi."
        let request = request(
            text,
        )
        let generated = DNeuralUltrasoundProposalGenerationResponse(
            proposals: [
                item(
                    .patientComplaints,
                    "painful urination",
                    "He complains of painful urination.",
                ),
                item(
                    .examinationDescription,
                    "Right kidney measures 110 mm. No calculi.",
                    "Right kidney measures 110 mm. No calculi.",
                ),
            ],
        )
        let result = try DNeuralUltrasoundProposalProcessor.validate(
            generated: generated,
            request: request,
        )
        let complaint = try #require(
            result.proposals.first { $0.id == .patientComplaints },
        )
        #expect(
            complaint.value == .text(
                "painful urination",
            ),
        )
        #expect(
            complaint.accuracy == .questionable,
        )
    }

    @Test(
        "An invented complaint without literal evidence is never completed",
    )
    func rejectsInventedComplaint() throws {
        let text = "On ultrasound no free fluid. Patient: Helen Carter."
        let result = try DNeuralUltrasoundProposalProcessor.validate(
            generated: .init(
                proposals: [
                    item(
                        .patientComplaints,
                        "No complaints.",
                        "Patient: Helen Carter.",
                    ),
                    item(
                        .examinationDescription,
                        "No free fluid.",
                        "On ultrasound no free fluid.",
                    ),
                ],
            ),
            request: request(
                text,
            ),
        )
        #expect(
            !result.proposals.contains { $0.id == .patientComplaints },
        )
    }

    @Test(
        "The next patient field cannot be appended to complaints",
    )
    func stopsBeforeMetadata() throws {
        let text = "Complaints: Pain at night. Patient: Helen Carter. On ultrasound no free fluid."
        let result = try DNeuralUltrasoundProposalProcessor.validate(
            generated: .init(
                proposals: [
                    item(
                        .patientComplaints,
                        "Pain at night.",
                        "Complaints: Pain at night.",
                    ),
                    item(
                        .examinationDescription,
                        "no free fluid.",
                        "On ultrasound no free fluid.",
                    ),
                ],
            ),
            request: request(
                text,
            ),
        )
        #expect(
            result.proposals.first { $0.id == .patientComplaints }?.value == .text(
                "Pain at night.",
            ),
        )
    }

    @Test(
        "Mixed model sections remain visible for physician review",
    )
    func separatesMixedDescription() throws {
        let text = "The patient complains of upper abdominal pain. No vomiting. Pancreatic head measures 22 mm. No free fluid."
        let result = try DNeuralUltrasoundProposalProcessor.validate(
            generated: .init(
                proposals: [
                    item(
                        .patientComplaints,
                        "upper abdominal pain",
                        text,
                    ),
                    item(
                        .examinationDescription,
                        text,
                        text,
                    ),
                ],
            ),
            request: request(
                text,
            ),
        )
        #expect(
            result.proposals.first { $0.id == .patientComplaints }?.value == .text(
                "upper abdominal pain",
            ),
        )
        #expect(
            result.proposals.first { $0.id == .examinationDescription }?.value == .text(
                text,
            ),
        )
        #expect(
            result.proposals.allSatisfy { $0.accuracy == .questionable },
        )
    }

    private func request(
        _ text: String,
    ) -> DNeuralUltrasoundDictationParseRequest {
        DNeuralUltrasoundDictationParseRequest(
            text: text,
            examinationTypeId: "abdominalCavity",
            examinationTypeTitle: "Unit-test examination",
            locale: Locale(
                identifier: "en",
            ),
            allowedFields: DNeuralUltrasoundVoiceFieldId.allCases,
            localization: VoiceLocalizationTestSupport.dictation(
                locale: Locale(
                    identifier: "en",
                ),
            ),
        )
    }

    private func item(
        _ id: DNeuralUltrasoundVoiceFieldId,
        _ value: String,
        _ evidence: String,
    ) -> DNeuralUltrasoundProposalGenerationItem {
        DNeuralUltrasoundProposalGenerationItem(
            fieldId: id,
            value: value,
            sourceQuote: evidence,
        )
    }
}
