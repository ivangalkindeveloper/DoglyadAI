#if DEBUG && DOGLYAD_REGRESSION
    @testable import Doglyad
    import DoglyadCamera
    import UIKit
    import UniformTypeIdentifiers
    import XCTest

    @MainActor
    final class PhotoLibraryRegressionTests: XCTestCase {
        func testUnavailableImageDoesNotDropOtherSelectedImagesOrChangeTheirOrder() async throws {
            let first = SimulatorCameraImageFactory.makeImage(
                captureNumber: 1,
            )
            let last = SimulatorCameraImageFactory.makeImage(
                captureNumber: 3,
            )
            let failed = NSItemProvider()
            failed.registerDataRepresentation(
                forTypeIdentifier: UTType.png.identifier,
                visibility: .all,
            ) { completion in
                completion(
                    nil,
                    CocoaError(
                        .fileReadCorruptFile,
                    ),
                )
                return nil
            }
            var completions: [[UIImage]] = []
            var failures: [Bool] = []
            let coordinator = PhotoLibraryPickerCoordinator(
                onComplete: { images, isFailure in
                    completions.append(
                        images,
                    )
                    failures.append(
                        isFailure,
                    )
                },
            )
            coordinator.loadSelection(
                providers: [NSItemProvider(
                    object: first,
                ), failed, NSItemProvider(
                    object: last,
                )],
            )
            for _ in 0 ..< 200 {
                if !completions.isEmpty {
                    break
                }
                try await Task.sleep(
                    for: .milliseconds(
                        10,
                    ),
                )
            }
            XCTAssertEqual(
                failures,
                [true],
            )
            XCTAssertEqual(
                completions.count,
                1,
            )
            XCTAssertEqual(
                completions.first?.count,
                2,
            )
            XCTAssertEqual(
                completions.first?.first?.pngData(),
                first.pngData(),
            )
            XCTAssertEqual(
                completions.first?.last?.pngData(),
                last.pngData(),
            )
            coordinator.loadSelection(
                providers: [],
            )
            XCTAssertEqual(
                completions.count,
                2,
            )
            XCTAssertTrue(
                completions.last?.isEmpty == true,
            )
            XCTAssertEqual(
                failures,
                [true, false],
            )
        }

        func testExportSevenSimulatorCameraImagesForTheSystemPhotoPicker() throws {
            let directory = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask,
            )[
                0,
            ]
            .appendingPathComponent(
                "RegressionGallery",
                isDirectory: true,
            )
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
            )
            for number in 1 ... 7 {
                let source = SimulatorCameraImageFactory.makeImage(
                    captureNumber: number,
                )
                let image: UIImage
                if number == 2 {
                    let format = UIGraphicsImageRendererFormat()
                    format.scale = 1
                    image = UIGraphicsImageRenderer(
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
                } else if number == 3 {
                    image = try UIImage(
                        cgImage: XCTUnwrap(
                            source.cgImage?.cropping(
                                to: CGRect(
                                    x: 128,
                                    y: 0,
                                    width: 768,
                                    height: 768,
                                ),
                            ),
                        ),
                    )
                } else {
                    image = source
                }
                let data = try XCTUnwrap(
                    image.pngData(),
                )
                try data.write(
                    to: directory.appendingPathComponent(
                        String(
                            format: "%02d-camera.png",
                            number,
                        ),
                    ),
                    options: .atomic,
                )
                XCTAssertNotNil(
                    UIImage(
                        data: data,
                    ),
                )
            }
            XCTAssertEqual(
                try FileManager.default.contentsOfDirectory(
                    atPath: directory.path,
                ).count(
                    where: {
                        $0.hasSuffix(
                            ".png",
                        )
                    },
                ),
                7,
            )
        }
    }
#endif
