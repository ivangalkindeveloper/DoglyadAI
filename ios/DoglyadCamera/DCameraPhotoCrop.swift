import CoreImage

enum DCameraPhotoCrop {
    static func crop(_ image: CIImage, to region: DCameraCropRegion) -> CIImage? {
        guard let normalized = region.normalizedRect(imageSize: image.extent.size) else { return nil }
        // Preview coordinates start at the top left; Core Image starts at the bottom left.
        let rect = CGRect(
            x: image.extent.minX + normalized.minX * image.extent.width,
            y: image.extent.minY + (1 - normalized.maxY) * image.extent.height,
            width: normalized.width * image.extent.width,
            height: normalized.height * image.extent.height
        ).integral.intersection(image.extent)
        guard !rect.isNull, !rect.isEmpty else { return nil }
        return image.cropped(to: rect)
    }
}
