import Combine
import UIKit

@MainActor
public final class SimulatorCameraController: DCameraController {
    @Published public private(set) var isLoading = false
    @Published public private(set) var isRunning = false
    @Published public private(set) var isCapturing = false

    private let previewLayer = CALayer()
    private var previewImage = SimulatorCameraImageFactory.makeImage(
        captureNumber: 0
    )
    private var captureNumber = 0
    private var capturePhotoCompletion: ((UIImage) -> Void)?

    init() {
        previewLayer.contents = previewImage.cgImage
        previewLayer.contentsGravity = .resizeAspectFill
    }

    public func startSession() {
        guard !isRunning else { return }
        isRunning = true
    }

    public func stopSession() {
        guard isRunning else { return }
        isRunning = false
    }

    public func takePhoto(
        completion: @escaping (UIImage) -> Void
    ) {
        guard !isCapturing else { return }

        isCapturing = true
        capturePhotoCompletion = completion
        captureNumber += 1
        let captureNumber = captureNumber

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 100000000)
            guard let self = self else { return }

            let image = SimulatorCameraImageFactory.makeImage(
                captureNumber: captureNumber
            )
            self.previewImage = image
            self.previewLayer.contents = image.cgImage
            self.isCapturing = false
            let completion = self.capturePhotoCompletion
            self.capturePhotoCompletion = nil
            completion?(image)
        }
    }

    public func makePreviewView() -> UIView {
        let view = UIView(frame: .zero)
        previewLayer.frame = UIScreen.main.bounds
        view.layer.addSublayer(previewLayer)
        return view
    }

    public func updatePreviewView(
        _ view: UIView
    ) {
        guard !view.bounds.isEmpty else { return }
        previewLayer.frame = view.bounds
    }
}
