import CoreGraphics

struct PhotoViewImageTransform {
    var scale: CGFloat = 1
    var offset: CGSize = .zero

    func zoomed(to newScale: CGFloat, around point: CGPoint, center: CGPoint) -> Self {
        let clampedScale = min(max(newScale, 1), 5)
        let ratio = clampedScale / scale
        return Self(
            scale: clampedScale,
            offset: CGSize(
                width: (center.x + offset.width - point.x) * ratio + point.x - center.x,
                height: (center.y + offset.height - point.y) * ratio + point.y - center.y
            )
        )
    }

    func constrained(imageSize: CGSize, viewport: CGSize, center: CGPoint) -> Self {
        guard scale > 1 else { return Self() }
        return Self(
            scale: scale,
            offset: CGSize(
                width: constrainedOffset(offset.width, length: imageSize.width * scale, viewport: viewport.width, center: center.x),
                height: constrainedOffset(offset.height, length: imageSize.height * scale, viewport: viewport.height, center: center.y)
            )
        )
    }

    private func constrainedOffset(_ offset: CGFloat, length: CGFloat, viewport: CGFloat, center: CGFloat) -> CGFloat {
        guard length > viewport else { return 0 }
        return min(max(offset, viewport - length / 2 - center), length / 2 - center)
    }
}
