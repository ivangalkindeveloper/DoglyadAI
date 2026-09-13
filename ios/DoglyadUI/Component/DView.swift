import SwiftUI

public protocol DView: View {
    var theme: DTheme { get }
}

public extension DView {
    var color: DColor { theme.color }
    var size: DSize { theme.size }
    var typography: DTypography { theme.typography }
}
