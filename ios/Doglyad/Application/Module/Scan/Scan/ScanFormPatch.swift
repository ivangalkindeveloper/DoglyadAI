import DoglyadNeuralModel
import Foundation

enum ScanFormPatch {
    static func apply(
        _ proposals: [DNeuralUltrasoundVoiceFieldProposal],
        to form: USExaminationDraftForm,
    ) -> USExaminationDraftForm? {
        var examinationNumber = form.examinationNumber
        var patientName = form.patientName
        var patientGender = form.patientGender
        var patientDateOfBirth = form.patientDateOfBirth
        var patientHeightCM = form.patientHeightCM
        var patientWeightKG = form.patientWeightKG
        var patientComplaints = form.patientComplaints
        var examinationDescription = form.examinationDescription
        var seen = Set<DNeuralUltrasoundVoiceFieldId>()

        for proposal in proposals {
            guard seen.insert(
                proposal.id,
            ).inserted else { return nil }
            switch proposal.id {
            case .examinationNumber:
                guard case let .text(
                    value,
                ) = proposal.value else { return nil }
                examinationNumber = value
            case .patientName:
                guard case let .text(
                    value,
                ) = proposal.value else { return nil }
                patientName = value
            case .patientGender:
                guard case let .gender(
                    value,
                ) = proposal.value else { return nil }
                switch value {
                case .male:
                    patientGender = .male
                case .female:
                    patientGender = .female
                }
            case .patientDateOfBirth:
                guard case let .date(
                    value,
                ) = proposal.value else { return nil }
                patientDateOfBirth = value
            case .patientHeightCM:
                guard case let .number(
                    value,
                ) = proposal.value else { return nil }
                patientHeightCM = String(
                    value,
                )
            case .patientWeightKG:
                guard case let .number(
                    value,
                ) = proposal.value else { return nil }
                patientWeightKG = String(
                    value,
                )
            case .patientComplaints:
                guard case let .text(
                    value,
                ) = proposal.value else { return nil }
                patientComplaints = value
            case .examinationDescription:
                guard case let .text(
                    value,
                ) = proposal.value else { return nil }
                examinationDescription = value
            }
        }

        return USExaminationDraftForm(
            examinationNumber: examinationNumber,
            patientName: patientName,
            patientGender: patientGender,
            patientDateOfBirth: patientDateOfBirth,
            patientHeightCM: patientHeightCM,
            patientWeightKG: patientWeightKG,
            patientComplaints: patientComplaints,
            examinationDescription: examinationDescription,
        )
    }
}
