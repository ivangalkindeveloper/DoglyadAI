import AVFoundation
import Combine
import CoreImage
import ImageIO
import UIKit

@MainActor
public final class DeviceCameraController: DCameraController {
    @Published public private(set) var isLoading = true
    @Published public private(set) var isRunning = false
    @Published public private(set) var isCapturing = false

    private nonisolated let session = AVCaptureSession()
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private nonisolated let output = AVCapturePhotoOutput()
    private nonisolated let delegate = DevicePhotoCaptureDelegate()

    private var capturePhotoCompletion: ((UIImage) -> Void)?

    private nonisolated let sessionQueue = DispatchQueue(
        label: "com.doglyad.camera.session",
        qos: .userInitiated
    )

    init() {
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        delegate.controller = self
        configureSession()
    }

    public func startSession() {
        guard !isRunning else { return }
        isRunning = true

        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            if !self.session.isRunning {
                self.session.startRunning()
            }
            let isRunning = self.session.isRunning
            Task { @MainActor in
                self.isRunning = isRunning
                self.previewLayer.connection?.isEnabled = isRunning
            }
        }
    }

    public func stopSession() {
        guard isRunning else { return }
        isRunning = false
        previewLayer.connection?.isEnabled = false
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    public func takePhoto(
        completion: @escaping (UIImage) -> Void
    ) {
        guard !isCapturing else { return }

        isCapturing = true
        capturePhotoCompletion = completion

        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            // The queue is serial, so configuration and startRunning() are already
            // guaranteed to have finished here — a capture never reaches a session
            // that has no active connection yet.
            guard self.session.isRunning,
                  let connection = self.output.connection(with: .video),
                  connection.isActive,
                  connection.isEnabled
            else {
                Task { @MainActor in
                    self.handleCaptureFailed()
                }
                return
            }

            self.output.capturePhoto(
                with: Self.makeSettings(output: self.output),
                delegate: self.delegate
            )
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

    fileprivate func handlePhotoCaptured(
        image: UIImage
    ) {
        isCapturing = false
        let completion = capturePhotoCompletion
        capturePhotoCompletion = nil
        completion?(image)
    }

    fileprivate func handleCaptureFailed() {
        isCapturing = false
        capturePhotoCompletion = nil
    }
}

private extension DeviceCameraController {
    func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            Self.configure(
                session: self.session,
                output: self.output
            )
            self.delegate.prepare()
            Task { @MainActor in
                self.isLoading = false
            }
        }
    }

    nonisolated static func configure(
        session: AVCaptureSession,
        output: AVCapturePhotoOutput
    ) {
        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ),
            let input = try? AVCaptureDeviceInput(device: device)
        else {
            return
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        guard session.canAddInput(input),
              session.canAddOutput(output)
        else {
            return
        }
        session.addInput(input)
        session.addOutput(output)

        // The frame is downscaled to scanPhotoResizeMaxDimension anyway, so 1080p
        // is more than enough for both the network and the preview. The .photo preset
        // would make the ISP process the full sensor frame.
        if session.canSetSessionPreset(.hd1920x1080) {
            session.sessionPreset = .hd1920x1080
        }

        // .balanced enables multi-frame fusion and waits for the scene to settle —
        // that is the main shutter delay. .speed captures a single frame.
        output.maxPhotoQualityPrioritization = .speed
        if output.isZeroShutterLagSupported {
            output.isZeroShutterLagEnabled = true
        }
        if output.isResponsiveCaptureSupported {
            output.isResponsiveCaptureEnabled = true
        }
        if output.isFastCapturePrioritizationSupported {
            output.isFastCapturePrioritizationEnabled = true
        }
    }

    nonisolated static func makeSettings(
        output: AVCapturePhotoOutput
    ) -> AVCapturePhotoSettings {
        let settings: AVCapturePhotoSettings

        // An uncompressed buffer removes the HEIC encode and the decode that follows:
        // the UIImage is assembled straight from pixels.
        if output.availablePhotoPixelFormatTypes.contains(kCVPixelFormatType_32BGRA) {
            settings = AVCapturePhotoSettings(
                format: [
                    kCVPixelBufferPixelFormatTypeKey as String: NSNumber(
                        value: kCVPixelFormatType_32BGRA
                    ),
                ]
            )
        } else {
            settings = AVCapturePhotoSettings()
        }

        settings.photoQualityPrioritization = .speed
        settings.flashMode = .off
        if output.isAutoRedEyeReductionSupported {
            settings.isAutoRedEyeReductionEnabled = false
        }

        return settings
    }
}

private final class DevicePhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    weak var controller: DeviceCameraController?

    // AVFoundation callbacks arrive on a single serial internal queue,
    // so lazy initialization is safe here.
    private lazy var ciContext = CIContext(options: [.useSoftwareRenderer: false])

    /// Warms up the CIContext outside the capture path so the first shot does not
    /// pay for creating it.
    func prepare() {
        _ = ciContext
    }

    func photoOutput(
        _: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil,
              let image = makeImage(from: photo)
        else {
            Task { @MainActor [controller] in
                controller?.handleCaptureFailed()
            }
            return
        }

        Task { @MainActor [controller] in
            controller?.handlePhotoCaptured(image: image)
        }
    }

    /// Builds a fully decoded UIImage from the pixel buffer, bypassing the codec.
    /// Orientation comes from the frame metadata — on an uncompressed buffer it is
    /// not applied, unlike EXIF in fileDataRepresentation().
    private func makeImage(
        from photo: AVCapturePhoto
    ) -> UIImage? {
        guard let pixelBuffer = photo.pixelBuffer else {
            guard let data = photo.fileDataRepresentation() else { return nil }
            return UIImage(data: data)?.preparingForDisplay()
        }

        let orientation = (photo.metadata[kCGImagePropertyOrientation as String] as? UInt32)
            .flatMap(CGImagePropertyOrientation.init)
            ?? .up
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}
