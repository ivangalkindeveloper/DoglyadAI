import CoreImage
@testable import DoglyadCamera
import Testing

struct CameraCropTests {
    @Test func mapsHorizontalAspectFillOverflow() throws {
        let region = DCameraCropRegion(
            rect: CGRect(x: 25, y: 50, width: 50, height: 100),
            previewSize: CGSize(width: 100, height: 200)
        )
        let rect = try #require(region.normalizedRect(imageSize: CGSize(width: 400, height: 200)))
        #expect(rect == CGRect(x: 0.4375, y: 0.25, width: 0.125, height: 0.5))
    }

    @Test func mapsVerticalAspectFillOverflow() throws {
        let region = DCameraCropRegion(
            rect: CGRect(x: 50, y: 25, width: 100, height: 50),
            previewSize: CGSize(width: 200, height: 100)
        )
        let rect = try #require(region.normalizedRect(imageSize: CGSize(width: 200, height: 400)))
        #expect(rect == CGRect(x: 0.25, y: 0.4375, width: 0.5, height: 0.125))
    }

    @Test func rejectsMissingOrOutOfBoundsGeometry() {
        let size = CGSize(width: 100, height: 100)
        for rect in [
            CGRect.zero,
            CGRect(x: -1, y: 0, width: 50, height: 50),
            CGRect(x: 80, y: 80, width: 30, height: 30),
        ] {
            #expect(DCameraCropRegion(rect: rect, previewSize: size).normalizedRect(imageSize: size) == nil)
        }
        let region = DCameraCropRegion(rect: CGRect(origin: .zero, size: size), previewSize: .zero)
        #expect(region.normalizedRect(imageSize: size) == nil)
    }

    @Test func convertsTopLeftCoordinatesAndNonzeroImageOrigin() throws {
        let image = CIImage(color: .red).cropped(to: CGRect(x: 20, y: 30, width: 100, height: 200))
        let region = DCameraCropRegion(
            rect: CGRect(x: 10, y: 20, width: 60, height: 40),
            previewSize: image.extent.size
        )
        let cropped = try #require(DCameraPhotoCrop.crop(image, to: region))
        #expect(cropped.extent == CGRect(x: 30, y: 170, width: 60, height: 40))
    }

    @Test func preservesFrameAspectRatioAfterEveryExifOrientation() throws {
        let raw = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        let region = DCameraCropRegion(
            rect: CGRect(x: 16, y: 200, width: 358, height: 358 * 2.0 / 3.0),
            previewSize: CGSize(width: 390, height: 844)
        )
        for orientation in [
            CGImagePropertyOrientation.up,
            .upMirrored,
            .down,
            .downMirrored,
            .left,
            .leftMirrored,
            .right,
            .rightMirrored,
        ] {
            let cropped = try #require(DCameraPhotoCrop.crop(raw.oriented(orientation), to: region))
            #expect(abs(cropped.extent.width - cropped.extent.height * 1.5) <= 2)
        }
    }

    @Test func cropsActualPixelsAfterOrientationIsApplied() throws {
        let blue = CIImage(color: .blue).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100))
        let red = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 50, width: 100, height: 50))
        let image = red.composited(over: blue)
        let region = DCameraCropRegion(
            rect: CGRect(x: 20, y: 10, width: 60, height: 30),
            previewSize: CGSize(width: 100, height: 100)
        )
        let context = CIContext(options: [.useSoftwareRenderer: true])
        for orientation in [CGImagePropertyOrientation.up, .down] {
            let cropped = try #require(DCameraPhotoCrop.crop(image.oriented(orientation), to: region))
            var pixel = [UInt8](repeating: 0, count: 4)
            pixel.withUnsafeMutableBytes { bytes in
                context.render(
                    cropped,
                    toBitmap: bytes.baseAddress!,
                    rowBytes: 4,
                    bounds: CGRect(x: cropped.extent.midX, y: cropped.extent.midY, width: 1, height: 1),
                    format: .RGBA8,
                    colorSpace: CGColorSpaceCreateDeviceRGB()
                )
            }
            switch orientation {
            case .up:
                #expect(pixel[0] > 250 && pixel[2] < 5)
            case .down:
                #expect(pixel[2] > 250 && pixel[0] < 5)
            case .upMirrored, .downMirrored, .leftMirrored, .right, .rightMirrored, .left:
                Issue.record("Unexpected test orientation")
            }
        }
    }
}
