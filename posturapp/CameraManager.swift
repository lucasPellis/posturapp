import AVFoundation
import Combine
import CoreImage

final class CameraManager: NSObject, ObservableObject, @unchecked Sendable {

    @Published var previewImage: CGImage?
    @Published var isRunning = false
    @Published var permissionDenied = false

    // nonisolated(unsafe): accessed from background sessionQueue, we own the thread safety
    nonisolated(unsafe) private let session = AVCaptureSession()
    nonisolated(unsafe) private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue", qos: .userInitiated)
    private let ciContext = CIContext()
    nonisolated(unsafe) var onSampleBuffer: (@Sendable (CMSampleBuffer) -> Void)?

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            sessionQueue.async { self.configureAndStart() }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.sessionQueue.async { self.configureAndStart() }
                } else {
                    DispatchQueue.main.async { self.permissionDenied = true }
                }
            }
        default:
            DispatchQueue.main.async { self.permissionDenied = true }
        }
    }

    func stop() {
        sessionQueue.async {
            self.session.stopRunning()
            DispatchQueue.main.async { self.isRunning = false }
        }
    }

    nonisolated private func configureAndStart() {
        session.beginConfiguration()
        session.sessionPreset = .vga640x480

        guard
            let device = cameraDevice(),
            let input = try? AVCaptureDeviceInput(device: device)
        else {
            session.commitConfiguration()
            return
        }

        if session.canAddInput(input) { session.addInput(input) }

        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true

        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }

        session.commitConfiguration()
        session.startRunning()

        DispatchQueue.main.async { self.isRunning = true }
    }

    nonisolated private func cameraDevice() -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(for: .video)
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        onSampleBuffer?(sampleBuffer)

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }

        DispatchQueue.main.async { self.previewImage = cgImage }
    }
}
