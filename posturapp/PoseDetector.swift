@preconcurrency import Vision
import Combine
import AVFoundation

final class PoseDetector: ObservableObject, @unchecked Sendable {

    @Published var joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint] = [:]
    @Published var bodyDetected = false

    nonisolated(unsafe) private let request = VNDetectHumanBodyPoseRequest()
    nonisolated(unsafe) private var lastProcessedTime: CFAbsoluteTime = 0
    private let throttleInterval: CFAbsoluteTime = 0.3

    nonisolated func process(sampleBuffer: CMSampleBuffer) {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastProcessedTime >= throttleInterval else { return }
        lastProcessedTime = now

        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return
        }

        guard let observation = request.results?.first else {
            DispatchQueue.main.async {
                self.joints = [:]
                self.bodyDetected = false
            }
            return
        }

        let allJoints = (try? observation.recognizedPoints(.all)) ?? [:]
        // Lower threshold so we capture joints even in partial/hunched positions
        let filtered = allJoints.filter { $0.value.confidence > 0.05 }

        DispatchQueue.main.async {
            self.joints = filtered
            self.bodyDetected = !filtered.isEmpty
        }
    }
}
