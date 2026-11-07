#if DEBUG && DOGLYAD_REGRESSION
    import Combine
    @testable import Doglyad
    import DoglyadCamera
    import Router
    import XCTest

    @MainActor
    final class ScanCameraRegressionTests: XCTestCase {
        func testCaptureRejectsDuplicatesLateCallbacksAndLimitOverflow() async throws {
            let container = DependencyContainer.previewable
            let camera = DCameraControllerFactory.make()
            var photos: [USExaminationScanPhoto] = []
            let model = ScanCameraViewModel(
                container: container,
                router: DRouter(
                    initialRoute: RouteScreen(
                        type: .scan,
                    ),
                ),
                getSubscriptionStatus: {
                    nil
                },
                observeSubscriptionStatus: { _ in
                    AnyCancellable {}
                },
                onSubscriptionStatusUpdated: { _ in },
                getSettingsAI: {
                    container.initialSettingsAI
                },
                onRefreshSubscriptionStatus: {},
                arguments: ScanCameraArguments(
                    cameraController: camera,
                    getPhotos: {
                        photos
                    },
                    onPhotosUpdated: {
                        photos = $0
                    },
                    photoMaxCount: 2,
                ),
            )
            model.onCameraAppear()
            model.onTapCapture()
            XCTAssertTrue(
                photos.isEmpty,
                "Capture must wait for valid crop coordinates",
            )
            model.updatePreviewFrame(
                CGRect(
                    x: 0,
                    y: 0,
                    width: 200,
                    height: 200,
                ),
            )
            model.updateCaptureFrame(
                CGRect(
                    x: 20,
                    y: 20,
                    width: 160,
                    height: 100,
                ),
            )
            model.onTapCapture()
            model.onTapCapture()
            try await waitForCount(
                1,
                photos: {
                    photos
                },
            )
            XCTAssertEqual(
                photos.count,
                1,
            )
            let first = try XCTUnwrap(
                photos.first?.id,
            )

            model.onTapCapture()
            model.onDisappear()
            try await Task.sleep(
                for: .milliseconds(
                    500,
                ),
            )
            XCTAssertEqual(
                photos.map(
                    \.id,
                ),
                [first],
                "A late capture must not change a closed module",
            )
            XCTAssertFalse(
                camera.isRunning,
            )

            model.onCameraAppear()
            XCTAssertTrue(
                camera.isRunning,
            )
            model.onTapCapture()
            try await waitForCount(
                2,
                photos: {
                    photos
                },
            )
            model.onTapCapture()
            try await Task.sleep(
                for: .milliseconds(
                    300,
                ),
            )
            XCTAssertEqual(
                photos.count,
                2,
                "Capture cannot exceed the configured limit",
            )
            model.onTapDeletePhoto(
                photo: photos[
                    0,
                ],
            )
            XCTAssertEqual(
                photos.count,
                1,
            )
            XCTAssertFalse(
                photos.contains {
                    $0.id == first
                },
            )
            model.onDisappear()
        }

        private func waitForCount(
            _ expected: Int,
            photos: () -> [USExaminationScanPhoto],
        ) async throws {
            for _ in 0 ..< 200 {
                if photos().count == expected {
                    return
                }
                try await Task.sleep(
                    for: .milliseconds(
                        10,
                    ),
                )
            }
            XCTFail(
                "Capture did not produce the expected number of photos",
            )
        }
    }

#endif
