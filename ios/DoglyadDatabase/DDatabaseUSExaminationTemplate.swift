import Foundation

public protocol DDatabaseUSExaminationTemplateProtocol: AnyObject {
    func getSelectedUSExaminationTemplateId() -> UUID?

    func setSelectedUSExaminationTemplateId(value: UUID)

    func removeSelectedUSExaminationTemplateId()
}

extension DDatabase: DDatabaseUSExaminationTemplateProtocol {
    public func getSelectedUSExaminationTemplateId() -> UUID? {
        guard let value = getString(.selectedUSExaminationTemplateId) else { return nil }
        return UUID(uuidString: value)
    }

    public func setSelectedUSExaminationTemplateId(value: UUID) {
        setValue(value.uuidString, .selectedUSExaminationTemplateId)
    }

    public func removeSelectedUSExaminationTemplateId() {
        removeValue(.selectedUSExaminationTemplateId)
    }
}
