import Foundation

@MainActor
protocol SelectUSExaminationTypeStateProtocol: AnyObject {
    var recentTypeIds: [String] {
        get
    }
    var currentValue: USExaminationType? {
        get
    }

    func copyWith(
        recentTypeIds: [String]?,
        currentValue: USExaminationType??,
    ) -> SelectUSExaminationTypeContentState
}
