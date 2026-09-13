import SwiftUI

public struct DCloseButton: DView {
    @EnvironmentObject public var theme: DTheme

    let action: () -> Void

    public init(
        action: @escaping () -> Void
    ) {
        self.action = action
    }

    public var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(color.grayscaleLine)
        }
    }
}

#Preview {
    DCloseButton {
        print("Close")
    }
    .padding()
    .dThemeWrapper()
}
