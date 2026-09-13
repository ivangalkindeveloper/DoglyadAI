import SwiftUI

public struct DCheckbox: DView {
    @EnvironmentObject public var theme: DTheme

    @Binding var isChecked: Bool

    public init(
        isChecked: Binding<Bool>
    ) {
        _isChecked = isChecked
    }

    public var body: some View {
        Button {
            isChecked.toggle()
        } label: {
            RoundedRectangle(cornerRadius: size.s4)
                .fill(isChecked ? color.primaryDefault : .clear)
                .overlay(
                    RoundedRectangle(cornerRadius: size.s4)
                        .stroke(
                            isChecked ? color.primaryDefault : color.grayscalePlacehold,
                            lineWidth: 1.5
                        )
                )
                .overlay {
                    if isChecked {
                        Image(systemName: "checkmark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: size.s10, height: size.s10)
                            .foregroundColor(color.grayscaleBackground)
                            .fontWeight(.bold)
                    }
                }
                .frame(width: size.s24, height: size.s24)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle().inset(by: -size.s12))
        .animation(theme.animation, value: isChecked)
    }
}

#Preview {
    @Previewable @State var isChecked = false

    HStack {
        DCheckbox(
            isChecked: $isChecked
        )
        Text("Accept terms")
    }
    .padding()
    .dThemeWrapper()
}
