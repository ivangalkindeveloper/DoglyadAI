import Foundation

public protocol DDatabaseOnBoardingProtocol: AnyObject {
    func getOnBoardingCompleted() -> Bool

    func setOnBoardingCompleted(
        isCompleted: Bool,
    )
}
