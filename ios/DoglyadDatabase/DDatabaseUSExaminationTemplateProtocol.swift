import Foundation

public protocol DDatabaseUSExaminationTemplateProtocol: AnyObject {
    func getSelectedUSExaminationTemplateId() -> UUID?

    func setSelectedUSExaminationTemplateId(
        value: UUID,
    )

    func removeSelectedUSExaminationTemplateId()
}
