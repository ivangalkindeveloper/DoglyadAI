import DoglyadUI
import SwiftUI

struct PhotoViewZoomableImage: DView {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: PhotoViewViewModel
    @EnvironmentObject var theme: DTheme

    let photoId: UUID
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
                if viewModel.isRemarksVisible {
                    ForEach(
                        Array(
                            viewModel.remarkPoints(
                                for: photoId,
                            ).enumerated(),
                        ),
                        id: \.element.id,
                    ) { index, point in
                        DImageAnnotationMarker(
                            title: point.title,
                            accessibilityLabel: l10n.resource(
                                .photoViewRemarkButton,
                                values: ["number": String(
                                    index + 1,
                                )],
                            ),
                            action: { viewModel.onTapRemark(
                                point,
                            ) },
                        )
                        .position(
                            displayed.position(
                                normalizedPoint: CGPoint(
                                    x: point.x,
                                    y: point.y,
                                ),
                                imageSize: imageSize,
                                center: center,
                            ),
                        )
                    }
                }
            }
            .frame(
                width: proxy.size.width,
                height: proxy.size.height,
            )
            .clipped()
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
