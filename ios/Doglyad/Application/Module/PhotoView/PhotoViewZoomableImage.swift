import DoglyadUI
import SwiftUI

struct PhotoViewZoomableImage: DView {
    @EnvironmentObject var theme: DTheme

    @EnvironmentObject private var viewModel: PhotoViewViewModel

    let image: UIImage
    let isSelected: Bool
    let contentInsets: EdgeInsets
    @State private var transform = PhotoViewImageTransform()
    @GestureState private var gestureValue: SimultaneousGesture<MagnifyGesture, DragGesture>.Value?

    var body: some View {
        GeometryReader { proxy in
            let imageSize = viewModel.fittedImageSize(
                image: image,
                contentInsets: contentInsets,
                in: proxy.size,
            )
            let center = CGPoint(
                x: (proxy.size.width + contentInsets.leading - contentInsets.trailing) / 2,
                y: (proxy.size.height + contentInsets.top - contentInsets.bottom) / 2,
            )
            let displayed = viewModel.transformed(
                transform: transform,
                by: gestureValue,
                imageSize: imageSize,
                viewport: proxy.size,
                center: center,
            )

            ZStack {
                Color.clear
                DImage(
                    uiImage: image,
                )
                .scaledToFit()
                .frame(
                    width: imageSize.width * displayed.scale,
                    height: imageSize.height * displayed.scale,
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: size.s16,
                    ),
                )
                .position(
                    x: center.x + displayed.offset.width,
                    y: center.y + displayed.offset.height,
                )
            }
            .frame(
                width: proxy.size.width,
                height: proxy.size.height,
            )
            .contentShape(
                Rectangle(),
            )
            .highPriorityGesture(
                MagnifyGesture()
                    .simultaneously(
                        with: DragGesture(
                            minimumDistance: transform.scale > 1 ? 10 : .greatestFiniteMagnitude,
                        ),
                    )
                    .updating(
                        $gestureValue,
                    ) { value, state, _ in
                        state = value
                    }
                    .onEnded { value in
                        transform = viewModel.transformed(
                            transform: transform,
                            by: value,
                            imageSize: imageSize,
                            viewport: proxy.size,
                            center: center,
                        )
                    },
            )
            .simultaneousGesture(
                SpatialTapGesture(
                    count: 2,
                )
                .onEnded { value in
                    withAnimation(
                        .easeInOut(
                            duration: 0.25,
                        ),
                    ) {
                        transform = viewModel.onDoubleTapPhoto(
                            transform: transform,
                            location: value.location,
                            imageSize: imageSize,
                            viewport: proxy.size,
                            center: center,
                        )
                    }
                },
            )
            .onChange(
                of: proxy.size,
            ) { _, _ in
                transform = PhotoViewImageTransform()
            }
        }
        .ignoresSafeArea(
            .container,
        )
        .onChange(
            of: isSelected,
        ) { _, _ in transform = PhotoViewImageTransform() }
    }
}
