@testable import Doglyad
import Foundation
import Testing

struct PhotoViewImageTransformTests {
    @Test func centerZoomDoesNotDrift() {
        let center = CGPoint(x: 200, y: 400)
        let result = PhotoViewImageTransform().zoomed(to: 3, around: center, center: center)
        #expect(result.offset == .zero)
        #expect(result.scale == 3)
    }

    @Test func offCenterZoomKeepsTheTouchedPixelInPlace() {
        let center = CGPoint(x: 200, y: 400)
        let touch = CGPoint(x: 260, y: 440)
        let initial = PhotoViewImageTransform(scale: 2, offset: CGSize(width: -30, height: 20))
        let result = initial.zoomed(to: 4, around: touch, center: center)
        let pixelX = (touch.x - center.x - initial.offset.width) / initial.scale
        let pixelY = (touch.y - center.y - initial.offset.height) / initial.scale
        #expect(center.x + result.offset.width + pixelX * result.scale == touch.x)
        #expect(center.y + result.offset.height + pixelY * result.scale == touch.y)
    }

    @Test func panningStopsAtImageEdges() {
        let result = PhotoViewImageTransform(scale: 3, offset: CGSize(width: 1000, height: -1000))
            .constrained(
                imageSize: CGSize(width: 300, height: 200),
                viewport: CGSize(width: 400, height: 800),
                center: CGPoint(x: 200, y: 400)
            )
        #expect(result.offset == CGSize(width: 250, height: 0))
    }

    @Test func minimumZoomReturnsToTheOriginalPosition() {
        let result = PhotoViewImageTransform(scale: 3, offset: CGSize(width: 100, height: 50))
            .zoomed(to: 0.1, around: .zero, center: CGPoint(x: 200, y: 400))
            .constrained(
                imageSize: CGSize(width: 300, height: 200),
                viewport: CGSize(width: 400, height: 800),
                center: CGPoint(x: 200, y: 400)
            )
        #expect(result.scale == 1)
        #expect(result.offset == .zero)
    }
}
