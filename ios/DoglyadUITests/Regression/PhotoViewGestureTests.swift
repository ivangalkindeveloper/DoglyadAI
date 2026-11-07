#if DEBUG && DOGLYAD_REGRESSION
    import XCTest

    final class PhotoViewGestureTests: XCTestCase {
        @MainActor
        func testDoubleTapAndPinch() {
            assertGestures(
                preview: "atlas-photoview-23a69732c2",
            )
        }

        @MainActor
        func testPortraitDoubleTapAndPinch() {
            assertGestures(
                preview: "atlas-photoview-a3683bb854",
            )
        }

        @MainActor
        func testSquareDoubleTapAndPinch() {
            assertGestures(
                preview: "atlas-photoview-dd0eb85c9e",
            )
        }

        @MainActor
        private func assertGestures(
            preview: String,
        ) {
            let app = XCUIApplication()
            app.launchArguments = [
                "-regressionPreview",
                preview,
                "-regressionCaptureSplash",
                "false",
            ]
            app.launch()
            let initialImage = app.descendants(
                matching: .any,
            ).matching(
                NSPredicate(
                    format: "identifier BEGINSWITH %@",
                    "photoView.image.",
                ),
            ).firstMatch
            XCTAssertTrue(
                initialImage.waitForExistence(
                    timeout: 20,
                ),
            )
            let prefix = initialImage.identifier.components(
                separatedBy: ".offset.",
            )[
                0,
            ] + ".offset."
            let image = app.descendants(
                matching: .any,
            ).matching(
                NSPredicate(
                    format: "identifier BEGINSWITH %@",
                    prefix,
                ),
            ).firstMatch
            image.doubleTap()
            let zoomed = app.descendants(
                matching: .any,
            ).matching(
                NSPredicate(
                    format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
                    prefix,
                    ".scale.250",
                ),
            ).firstMatch
            XCTAssertTrue(
                zoomed.waitForExistence(
                    timeout: 5,
                ),
                "Double tap must zoom to 2.5",
            )
            zoomed.pinch(
                withScale: 1.4,
                velocity: 1,
            )
            let scale = Int(
                image.identifier.components(
                    separatedBy: ".scale.",
                ).last ?? "",
            ) ?? 0
            XCTAssertGreaterThan(
                scale,
                250,
                "Pinch must increase the current scale",
            )
            let beforePan = image.identifier
            let start = app.coordinate(
                withNormalizedOffset: CGVector(
                    dx: 0.5,
                    dy: 0.5,
                ),
            )
            let end = app.coordinate(
                withNormalizedOffset: CGVector(
                    dx: 0.7,
                    dy: 0.6,
                ),
            )
            start.press(
                forDuration: 0.1,
                thenDragTo: end,
            )
            XCTAssertNotEqual(
                image.identifier,
                beforePan,
                "Pan must move the zoomed image",
            )
            XCTAssertTrue(
                image.identifier.hasSuffix(
                    ".scale.\(scale)",
                ),
                "Pan must retain the zoom",
            )
            image.doubleTap()
            let reset = app.descendants(
                matching: .any,
            ).matching(
                NSPredicate(
                    format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
                    prefix,
                    ".scale.100",
                ),
            ).firstMatch
            XCTAssertTrue(
                reset.waitForExistence(
                    timeout: 5,
                ),
                "Second double tap must restore the fitted image",
            )
        }
    }

#endif
