import Foundation

public protocol DDatabaseOnBoardingProtocol: AnyObject {
    func getOnBoardingCompleted() -> Bool

    func setOnBoardingCompleted(
        value: Bool,
    )
}

extension DDatabase: DDatabaseOnBoardingProtocol {
    public func getOnBoardingCompleted() -> Bool {
        getBool(
            .isOnBoardingCompleted,
        )
    }

    public func setOnBoardingCompleted(
        value: Bool,
    ) {
        setValue(
            value,
            .isOnBoardingCompleted,
        )
    }
}
