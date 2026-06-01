@preconcurrency import Vision
import Combine
import AVFoundation

final class PoseDetector: ObservableObject, @unchecked Sendable {

    @Published var joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint] = [:]
    @Published var bodyDetected = false

    /// Set after calibration to lock detection onto the person at the desk.
    /// Normalized Vision X coordinate of the calibrated user's shoulder midpoint.
    var subjectAnchorX: CGFloat? = nil

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

        guard let results = request.results, !results.isEmpty else {
            DispatchQueue.main.async {
                self.joints = [:]
                self.bodyDetected = false
            }
            return
        }

        let observation = bestObservation(from: results, anchorX: subjectAnchorX)
        let allJoints = (try? observation?.recognizedPoints(.all)) ?? [:]
        let filtered = allJoints.filter { $0.value.confidence > 0.05 }

        DispatchQueue.main.async {
            self.joints = filtered
            self.bodyDetected = !filtered.isEmpty
        }
    }

    // MARK: - Subject selection

    /// Picks the most relevant observation from potentially multiple detected bodies.
    /// With anchor: prefers the observation closest to the calibrated shoulder X.
    /// Without anchor: prefers the observation with the most confident joints (closest to camera).
    private func bestObservation(
        from results: [VNHumanBodyPoseObservation],
        anchorX: CGFloat?
    ) -> VNHumanBodyPoseObservation? {

        if let anchor = anchorX {
            return results.min { obsA, obsB in
                let dA = abs((shoulderMidX(obs: obsA) ?? 999) - anchor)
                let dB = abs((shoulderMidX(obs: obsB) ?? 999) - anchor)
                return dA < dB
            }
        }

        // No anchor: pick observation with most joints detected above threshold
        return results.max { obsA, obsB in
            jointCount(obs: obsA) < jointCount(obs: obsB)
        }
    }

    private func shoulderMidX(obs: VNHumanBodyPoseObservation) -> CGFloat? {
        guard let points = try? obs.recognizedPoints(.all),
              let l = points[.leftShoulder],
              let r = points[.rightShoulder],
              l.confidence > 0.1, r.confidence > 0.1
        else { return nil }
        return (l.location.x + r.location.x) / 2
    }

    private func jointCount(obs: VNHumanBodyPoseObservation) -> Int {
        ((try? obs.recognizedPoints(.all))?.filter { $0.value.confidence > 0.05 }.count) ?? 0
    }
}
