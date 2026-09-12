import Foundation

public protocol DDatabaseProtocol: AnyObject,
    DDatabaseOnBoardingProtocol,
    DDatabaseLegalProtocol,
    DDatabaseNeuralModelSettingsProtocol,
    DDatabaseUSExaminationTypeProtocol,
    DDatabaseUSExaminationNeuralModelProtocol,
    DDatabaseUserSettingsProtocol,
    DDatabaseClearProtocol
{
    var examinationReports: DExaminationReportsStore { get }
    var examinationTemplates: DExaminationTemplatesStore { get }
}
