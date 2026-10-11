@testable import Doglyad
import Foundation
import Testing

struct PhotoViewImageTransformTests {
    @Test func annotationCoordinatesFollowImageScaleAndOffset() {
        let center = CGPoint(
            x: 200,
            y: 400,
        )
        let imageSize = CGSize(
            width: 300,
            height: 200,
        )
        let normalized = CGPoint(
            x: 0.25,
            y: 0.75,
        )
        let initial = PhotoViewImageTransform().position(
            normalizedPoint: normalized,
            imageSize: imageSize,
            center: center,
        )
        #expect(
            initial == CGPoint(
                x: 125,
                y: 450,
            ),
        )
        let transform = PhotoViewImageTransform(
            scale: 3,
            offset: CGSize(
                width: 20,
                height: -40,
            ),
        )
        let result = transform.position(
            normalizedPoint: normalized,
            imageSize: imageSize,
            center: center,
        )
        #expect(
            result == CGPoint(
                x: -5,
                y: 510,
            ),
        )
        #expect(
            transform.position(
                normalizedPoint: CGPoint(
                    x: 0.5,
                    y: 0.5,
                ),
                imageSize: imageSize,
                center: center,
            ) == CGPoint(
                x: 220,
                y: 360,
            ),
        )
    }

    @Test func zoomAroundAnnotationKeepsItAtTheTouchedPosition() {
        let center = CGPoint(
            x: 200,
            y: 400,
        )
        let imageSize = CGSize(
            width: 300,
            height: 200,
        )
        let normalized = CGPoint(
            x: 0.75,
            y: 0.25,
        )
        let initial = PhotoViewImageTransform()
        let position = initial.position(
            normalizedPoint: normalized,
            imageSize: imageSize,
            center: center,
        )
        let zoomed = initial.zoomed(
            to: 3,
            around: position,
            center: center,
        )
        #expect(
            zoomed.position(
                normalizedPoint: normalized,
                imageSize: imageSize,
                center: center,
            ) == position,
        )
    }

    @Test func centerZoomDoesNotDrift() {
        let center = CGPoint(
            x: 200,
            y: 400,
        )
        let result = PhotoViewImageTransform().zoomed(
            to: 3,
            around: center,
            center: center,
        )
        #expect(
            result.offset == .zero,
        )
        #expect(
            result.scale == 3,
        )
    }

    @Test func offCenterZoomKeepsTheTouchedPixelInPlace() {
        let center = CGPoint(
            x: 200,
            y: 400,
        )
        let touch = CGPoint(
            x: 260,
            y: 440,
        )
        let initial = PhotoViewImageTransform(
            scale: 2,
            offset: CGSize(
                width: -30,
                height: 20,
            ),
        )
        let result = initial.zoomed(
            to: 4,
            around: touch,
            center: center,
        )
        let pixelX = (touch.x - center.x - initial.offset.width) / initial.scale
        let pixelY = (touch.y - center.y - initial.offset.height) / initial.scale
        #expect(
            center.x + result.offset.width + pixelX * result.scale == touch.x,
        )
        #expect(
            center.y + result.offset.height + pixelY * result.scale == touch.y,
        )
    }

    @Test func panningStopsAtImageEdges() {
        let result = PhotoViewImageTransform(
            scale: 3,
            offset: CGSize(
                width: 1000,
                height: -1000,
            ),
        )
        .constrained(
            imageSize: CGSize(
                width: 300,
                height: 200,
            ),
            viewport: CGSize(
                width: 400,
                height: 800,
            ),
            center: CGPoint(
                x: 200,
                y: 400,
            ),
        )
        #expect(
            result.offset == CGSize(
                width: 250,
                height: 0,
            ),
        )
    }

    @Test func minimumZoomReturnsToTheOriginalPosition() {
        let result = PhotoViewImageTransform(
            scale: 3,
            offset: CGSize(
                width: 100,
                height: 50,
            ),
        )
        .zoomed(
            to: 0.1,
            around: .zero,
            center: CGPoint(
                x: 200,
                y: 400,
            ),
        )
        .constrained(
            imageSize: CGSize(
                width: 300,
                height: 200,
            ),
            viewport: CGSize(
                width: 400,
                height: 800,
            ),
            center: CGPoint(
                x: 200,
                y: 400,
            ),
        )
        #expect(
            result.scale == 1,
        )
        #expect(
            result.offset == .zero,
        )
    }
}
