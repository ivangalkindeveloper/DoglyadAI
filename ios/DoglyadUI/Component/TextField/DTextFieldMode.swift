import SwiftUI

public protocol DTextFieldMode {
    var axis: Axis { get }
    var lineLimit: ClosedRange<Int> { get }
    var submitLabel: SubmitLabel { get }
}
