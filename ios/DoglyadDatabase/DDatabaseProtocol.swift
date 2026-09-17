import Foundation

public protocol DDatabaseProtocol: AnyObject,
    DDatabaseOnBoardingProtocol,
    DDatabaseLegalProtocol,
    DDatabaseNeuralModelSettingsProtocol,
    DDatabaseUSExaminationTemplateProtocol,
    DDatabaseUSExaminationTypeProtocol,
    DDatabaseUSExaminationNeuralModelProtocol,
    DDatabaseUserSettingsProtocol,
    DDatabaseClearProtocol
{
    var examinationReports: DExaminationReportsStore { get }
    var examinationTemplates: DExaminationTemplatesStore { get }
    var examinationDraft: DExaminationDraftStore { get }
}
