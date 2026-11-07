#if DEBUG
    import DoglyadCamera
    import UIKit

    @MainActor
    enum PhotoViewPreviewFactory {
        static let portraitPhotos = [USExaminationScanPhoto(
            image: makePortrait(),
        )]
        static let squarePhotos = [USExaminationScanPhoto(
            image: makeSquare(),
        )]

        private static func makePortrait() -> UIImage {
            let source = SimulatorCameraImageFactory.makeImage(
                captureNumber: 2,
            )
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            return UIGraphicsImageRenderer(
                size: CGSize(
                    width: source.size.height,
                    height: source.size.width,
                ),
                format: format,
            ).image { context in
                context.cgContext.translateBy(
                    x: source.size.height,
                    y: 0,
                )
                context.cgContext.rotate(
                    by: .pi / 2,
                )
                source.draw(
                    at: .zero,
                )
            }
        }

        private static func makeSquare() -> UIImage {
            let source = SimulatorCameraImageFactory.makeImage(
                captureNumber: 3,
            )
            let side = min(
                source.size.width,
                source.size.height,
            )
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            return UIGraphicsImageRenderer(
                size: CGSize(
                    width: side,
                    height: side,
                ),
                format: format,
            ).image { _ in
                source.draw(
                    at: CGPoint(
                        x: (side - source.size.width) / 2,
                        y: (side - source.size.height) / 2,
                    ),
                )
            }
        }
    }
#endif
