import SwiftUI

public final class DTextFieldMultiLineMode: DTextFieldMode {
    public let axis: Axis = .vertical
    public let lineLimit: ClosedRange<Int>
    public let submitLabel: SubmitLabel = .return

    public init(
        lineLimit: ClosedRange<Int> = 3 ... 8
    ) {
        self.lineLimit = lineLimit
    }
}
