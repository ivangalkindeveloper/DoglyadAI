import DoglyadUI
import SwiftUI

struct PhotoViewZoomableImage: DView {
    @EnvironmentObject var theme: DTheme

    let image: UIImage
    let isSelected: Bool
    let contentInsets: EdgeInsets
    @State private var scale: CGFloat = 1
    @GestureState private var magnification: CGFloat = 1

    private var effectiveScale: CGFloat { min(max(scale * magnification, 1), 5) }

    var body: some View {
        GeometryReader { proxy in
            let imageSize = fittedImageSize(in: proxy.size)

            ScrollView(
                [.horizontal, .vertical],
                showsIndicators: false
            ) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: imageSize.width * effectiveScale,
                        height: imageSize.height * effectiveScale
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: size.s16)
                    )
                    .padding(contentInsets)
                    .frame(
                        minWidth: proxy.size.width,
                        minHeight: proxy.size.height
                    )
            }
            .scrollClipDisabled()
            .ignoresSafeArea(.container)
            .scrollDisabled(effectiveScale <= 1)
            .simultaneousGesture(
                MagnifyGesture()
                    .updating($magnification) { value, state, _ in
                        state = value.magnification
                    }
                    .onEnded { value in
                        scale = min(max(scale * value.magnification, 1), 5)
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation { scale = scale > 1 ? 1 : 2 }
            }
        }
        .ignoresSafeArea(.container)
        .onChange(of: isSelected) { _, _ in scale = 1 }
    }

    private func fittedImageSize(in viewport: CGSize) -> CGSize {
        guard image.size.width > 0, image.size.height > 0 else { return .zero }
        let availableWidth = max(viewport.width - contentInsets.leading - contentInsets.trailing, 0)
        let availableHeight = max(viewport.height - contentInsets.top - contentInsets.bottom, 0)
        let fitScale = min(availableWidth / image.size.width, availableHeight / image.size.height)
        return CGSize(
            width: image.size.width * fitScale,
            height: image.size.height * fitScale
        )
    }
}
