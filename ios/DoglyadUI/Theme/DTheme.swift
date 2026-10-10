import Combine
import SwiftUI

public class DTheme: ObservableObject {
    @Published public var color: DColor
    @Published public var size: DSize
    @Published public var typography: DTypography
    @Published public var animation: Animation? = .spring(
        response: 0.5,
        dampingFraction: 0.75,
        blendDuration: 1,
    )

    public init(
        color: DColor,
        size: DSize,
        typography: DTypography,
    ) {
        self.color = color
        self.size = size
        self.typography = typography
    }
}

public extension DTheme {
    static let light = DTheme(
        color: DColor.light,
        size: DSize.shared,
        typography: DTypography.shared,
    )

    func changeColor(
        color: DColor,
    ) {
        self.color = color
    }
}
