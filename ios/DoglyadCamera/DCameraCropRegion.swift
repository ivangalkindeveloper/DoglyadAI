import CoreGraphics

/// The scan frame in preview-local coordinates, captured at shutter time.
public struct DCameraCropRegion: Sendable {
    public let rect: CGRect
    public let previewSize: CGSize

    public init(rect: CGRect, previewSize: CGSize) {
        self.rect = rect
        self.previewSize = previewSize
    }

    /// Maps an aspect-fill preview to an image with the same orientation/mirroring.
    func normalizedRect(imageSize: CGSize) -> CGRect? {
        let values = [
            rect.minX,
            rect.minY,
            rect.width,
            rect.height,
            previewSize.width,
            previewSize.height,
            imageSize.width,
            imageSize.height,
        ]
        guard values.allSatisfy(\.isFinite),
              rect.width > 0, rect.height > 0,
              previewSize.width > 0, previewSize.height > 0,
              imageSize.width > 0, imageSize.height > 0,
              CGRect(origin: .zero, size: previewSize).contains(rect)
        else { return nil }

        let scale = max(previewSize.width / imageSize.width, previewSize.height / imageSize.height)
        let displayedWidth = imageSize.width * scale
        let displayedHeight = imageSize.height * scale
        return CGRect(
            x: (rect.minX + (displayedWidth - previewSize.width) / 2) / displayedWidth,
            y: (rect.minY + (displayedHeight - previewSize.height) / 2) / displayedHeight,
            width: rect.width / displayedWidth,
            height: rect.height / displayedHeight
        )
    }
}
