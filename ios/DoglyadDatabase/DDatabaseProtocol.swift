import Foundation

public protocol DDatabaseProtocol: AnyObject,
    DDatabaseOnBoardingProtocol,
    DDatabaseLegalProtocol,
    DDatabaseSettingsAIProtocol,
    DDatabaseUSExaminationTemplateProtocol,
    DDatabaseUSExaminationTypeProtocol,
    DDatabaseUserSettingsProtocol,
    DDatabaseClearProtocol
{
    var examinationReports: DExaminationReportsStore { get }
    var examinationTemplates: DExaminationTemplatesStore { get }
    var examinationDraft: DExaminationDraftStore { get }
}
