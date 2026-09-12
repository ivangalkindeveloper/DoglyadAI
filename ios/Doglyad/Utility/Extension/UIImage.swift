import UIKit

extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let aspectRatio = size.width / size.height
        let targetSize: CGSize

        if size.width > size.height {
            targetSize = CGSize(
                width: min(size.width, maxDimension),
                height: min(size.width, maxDimension) / aspectRatio
            )
        } else {
            targetSize = CGSize(
                width: min(size.height, maxDimension) * aspectRatio,
                height: min(size.height, maxDimension)
            )
        }

        guard targetSize.width < size.width else { return self }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(
            size: targetSize,
            format: format
        )
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    /// Decodes and downscales the image once so that lists do not decode
    /// the full frame on the main thread while rendering previews.
    /// The result is a bitmap of exactly `maxDimension` pixels on its longer side
    /// (scale = 1) rather than at screen scale.
    func thumbnail(maxDimension: CGFloat) -> UIImage {
        let maxSide = max(size.width, size.height)
        guard maxSide > 0 else { return self }

        let ratio = min(1, maxDimension / maxSide)
        let targetSize = CGSize(
            width: max(1, (size.width * ratio).rounded()),
            height: max(1, (size.height * ratio).rounded())
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(
            size: targetSize,
            format: format
        )
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
