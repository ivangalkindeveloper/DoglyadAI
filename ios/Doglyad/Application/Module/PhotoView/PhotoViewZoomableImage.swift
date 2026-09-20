import DoglyadUI
import SwiftUI

struct PhotoViewZoomableImage: DView {
    @EnvironmentObject var theme: DTheme

    let image: UIImage
    let isSelected: Bool
    let contentInsets: EdgeInsets
    @State private var transform = PhotoViewImageTransform()
    @GestureState private var gestureValue: SimultaneousGesture<MagnifyGesture, DragGesture>.Value?

    var body: some View {
        GeometryReader { proxy in
            let imageSize = fittedImageSize(in: proxy.size)
            let center = CGPoint(
                x: (proxy.size.width + contentInsets.leading - contentInsets.trailing) / 2,
                y: (proxy.size.height + contentInsets.top - contentInsets.bottom) / 2
            )
            let displayed = transformed(
                by: gestureValue,
                imageSize: imageSize,
                viewport: proxy.size,
                center: center
            )

            ZStack {
                Color.clear
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: imageSize.width * displayed.scale,
                        height: imageSize.height * displayed.scale
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: size.s16)
                    )
                    .position(
                        x: center.x + displayed.offset.width,
                        y: center.y + displayed.offset.height
                    )
            }
            .frame(
                width: proxy.size.width,
                height: proxy.size.height
            )
            .contentShape(Rectangle())
            .highPriorityGesture(
                MagnifyGesture()
                    .simultaneously(with: DragGesture(
                        minimumDistance: transform.scale > 1 ? 10 : .greatestFiniteMagnitude
                    ))
                    .updating($gestureValue) { value, state, _ in
                        state = value
                    }
                    .onEnded { value in
                        transform = transformed(
                            by: value,
                            imageSize: imageSize,
                            viewport: proxy.size,
                            center: center
                        )
                    }
            )
            .simultaneousGesture(
                SpatialTapGesture(count: 2)
                    .onEnded { value in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            transform = transform.scale > 1
                                ? PhotoViewImageTransform()
                                : transform.zoomed(to: 2.5, around: value.location, center: center)
                                .constrained(imageSize: imageSize, viewport: proxy.size, center: center)
                        }
                    }
            )
            .onChange(of: proxy.size) { _, _ in
                transform = PhotoViewImageTransform()
            }
        }
        .ignoresSafeArea(.container)
        .onChange(of: isSelected) { _, _ in transform = PhotoViewImageTransform() }
    }

    private func transformed(
        by value: SimultaneousGesture<MagnifyGesture, DragGesture>.Value?,
        imageSize: CGSize,
        viewport: CGSize,
        center: CGPoint
    ) -> PhotoViewImageTransform {
        var result = transform
        if let pinch = value?.first {
            result = transform.zoomed(
                to: transform.scale * pinch.magnification,
                around: CGPoint(
                    x: pinch.startAnchor.x * viewport.width,
                    y: pinch.startAnchor.y * viewport.height
                ),
                center: center
            )
        } else if let drag = value?.second {
            result.offset.width += drag.translation.width
            result.offset.height += drag.translation.height
        }
        return result.constrained(imageSize: imageSize, viewport: viewport, center: center)
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
