import DoglyadUI
import SwiftUI

struct PhotoCardView: DView {
    @EnvironmentObject var theme: DTheme

    let image: UIImage
    let actionDelete: (() -> Void)?
    let onTap: (() -> Void)?

    init(
        image: UIImage,
        actionDelete: (() -> Void)? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.image = image
        self.actionDelete = actionDelete
        self.onTap = onTap
    }

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(
                width: size.s64,
                height: size.s64
            )
            .clipped()
            .cornerRadius(size.adaptiveCornerRadius / 4)
            .onTapGesture { onTap?() }
            .accessibilityAddTraits(onTap == nil ? [] : .isButton)
            .if(actionDelete != nil) { view in
                view
                    .padding(.top, size.s8)
                    .padding(.trailing, size.s8)
                    .overlay(alignment: .topTrailing) {
                        Button(action: actionDelete ?? {}) {
                            ZStack {
                                Circle().fill(color.dangerDefaultWeak)
                                Image(.close)
                                    .resizable()
                                    .renderingMode(.template)
                                    .foregroundColor(color.dangerDefault)
                                    .frame(
                                        width: size.s16,
                                        height: size.s16
                                    )
                            }
                        }
                        .frame(
                            width: size.s24,
                            height: size.s24
                        )
                        .buttonStyle(PlainButtonStyle())
                    }
            }
    }
}

#Preview {
    PhotoCardView(
        image: .alertInfo,
        actionDelete: {}
    )
    .padding()
    .dThemeWrapper()
}
