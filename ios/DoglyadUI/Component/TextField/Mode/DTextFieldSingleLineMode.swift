import SwiftUI

public final class DTextFieldSingleLineMode: DTextFieldMode {
    public let axis: Axis = .horizontal
    public let lineLimit: ClosedRange<Int> = 1 ... 1
    public let submitLabel: SubmitLabel

    public init(
        submitLabel: SubmitLabel = .done
    ) {
        self.submitLabel = submitLabel
    }
}
