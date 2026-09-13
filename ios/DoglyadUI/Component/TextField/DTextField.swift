import SwiftUI

public struct DTextField<Focus: Hashable, Leading: View, Trailing: View>: DView {
    @EnvironmentObject public var theme: DTheme

    @ObservedObject private var controller: DTextFieldController
    private let focus: DTextFieldFocus<Focus>?
    private let title: LocalizedStringResource
    private let placeholder: LocalizedStringResource
    private let mode: any DTextFieldMode
    private let keyboardType: UIKeyboardType
    private let autocapitalization: TextInputAutocapitalization?
    private let leading: Leading
    private let trailing: Trailing

    @FocusState private var internalFocus: Bool
    private var isFocused: Bool {
        focus?.isFocused ?? internalFocus
    }

    public init(
        controller: DTextFieldController,
        focus: DTextFieldFocus<Focus>? = nil,
        title: LocalizedStringResource,
        placeholder: LocalizedStringResource,
        mode: any DTextFieldMode = DTextFieldSingleLineMode(),
        keyboardType: UIKeyboardType = .default,
        autocapitalization: TextInputAutocapitalization? = .sentences,
        @ViewBuilder leading: @escaping (() -> Leading) = { EmptyView() },
        @ViewBuilder trailing: @escaping (() -> Trailing) = { EmptyView() }
    ) {
        self.controller = controller
        self.focus = focus
        self.title = title
        self.placeholder = placeholder
        self.mode = mode
        self.keyboardType = keyboardType
        self.autocapitalization = autocapitalization
        self.leading = leading()
        self.trailing = trailing()
    }

    public init(
        controller: DTextFieldController,
        title: LocalizedStringResource,
        placeholder: LocalizedStringResource,
        mode: any DTextFieldMode = DTextFieldSingleLineMode(),
        keyboardType: UIKeyboardType = .default,
        autocapitalization: TextInputAutocapitalization? = .sentences,
        @ViewBuilder leading: @escaping (() -> Leading) = { EmptyView() },
        @ViewBuilder trailing: @escaping (() -> Trailing) = { EmptyView() }
    ) where Focus == Bool {
        self.init(
            controller: controller,
            focus: nil,
            title: title,
            placeholder: placeholder,
            mode: mode,
            keyboardType: keyboardType,
            autocapitalization: autocapitalization,
            leading: leading,
            trailing: trailing
        )
    }

    public var body: some View {
        VStack(
            alignment: .leading,
            spacing: .zero
        ) {
            ZStack {
                RoundedRectangle(cornerRadius: size.s16)
                    .fill(fillColor)
                    .stroke(borderColor, lineWidth: 1)

                HStack(spacing: .zero) {
                    if !(leading is EmptyView) {
                        leading.fixedSize()
                            .padding(.leading, size.s16)
                    }

                    VStack(
                        alignment: .leading,
                        spacing: .zero
                    ) {
                        Text(title)
                            .font(.custom(.MontserratRegular, size.s10))
                            .foregroundStyle(titleColor)
                            .padding(.bottom, size.s2)

                        let field = TextField(
                            placeholder,
                            text: $controller.text,
                            prompt: Text(verbatim: String(localized: placeholder))
                                .foregroundStyle(color.grayscalePlacehold),
                            axis: mode.axis
                        )
                        Group {
                            if let focus {
                                field.focused(focus.state, equals: focus.value)
                            } else {
                                field.focused($internalFocus)
                            }
                        }
                        .font(typography.textSmall)
                        .foregroundStyle(color.grayscaleHeader)
                        .multilineTextAlignment(.leading)
                        .tint(borderColor)
                        .lineLimit(mode.lineLimit)
                        .keyboardType(keyboardType)
                        .submitLabel(mode.submitLabel)
                        .textInputAutocapitalization(autocapitalization)
                    }

                    if !(trailing is EmptyView) {
                        trailing.fixedSize()
                            .padding(.leading, size.s16)
                    }
                }
                .padding(size.s10)
            }

            if let error = controller.errorText, !error.isEmpty {
                Text(error)
                    .font(typography.textSmall)
                    .foregroundStyle(color.dangerDefault)
                    .padding(.top, size.s4)
                    .padding(.horizontal, size.s16)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .onTapGesture {
            guard focus == nil && self.isFocused == false else { return }
            self.internalFocus = true
        }
        .onChange(of: controller.text) {
            if self.controller.isError {
                self.controller.isError = false
            }
            if self.controller.errorText != nil {
                self.controller.errorText = nil
            }
        }
        .animation(
            theme.animation,
            value: isFocused
        )
    }
}

private extension DTextField {
    var fillColor: Color {
        if controller.isError || controller.errorText != nil { return color.dangerBackground }
        return color.grayscaleBackground
    }

    var titleColor: Color {
        if controller.isError || controller.errorText != nil { return color.dangerDefault }
        return isFocused ? color.primaryDefault : color.grayscalePlacehold
    }

    var borderColor: Color {
        if controller.isError || controller.errorText != nil { return color.dangerDefault }
        return isFocused ? color.primaryDefault : .clear
    }
}

#Preview {
    @Previewable let sampleText = "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum."
    @Previewable @State var controller = DTextFieldController()

    VStack {
        Spacer()
        DTextField(
            controller: controller,
            title: "Some title",
            placeholder: "Some placeholder for filling...",
            mode: DTextFieldMultiLineMode()
        )
        Spacer()
        Button(
            "Show error"
        ) {
            controller.showError(text: "Some Error")
        }
        Button(
            "Set sample text"
        ) {
            controller.text = sampleText
        }
    }
    .padding()
    .background(.gray)
    .dThemeWrapper()
}
