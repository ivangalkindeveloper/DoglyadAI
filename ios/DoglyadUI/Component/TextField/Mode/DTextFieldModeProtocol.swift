import SwiftUI

public protocol DTextFieldModeProtocol {
    var axis: Axis { get }
    var lineLimit: ClosedRange<Int> { get }
    var submitLabel: SubmitLabel { get }
}
