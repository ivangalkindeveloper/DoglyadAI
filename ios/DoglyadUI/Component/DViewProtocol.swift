import SwiftUI

public protocol DViewProtocol: View {
    var theme: DTheme { get }
}

public extension DViewProtocol {
    var color: DColor { theme.color }
    var size: DSize { theme.size }
    var typography: DTypography { theme.typography }
}
