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

    private func bestObservation(
        from results: [VNHumanBodyPoseObservation],
        anchorX: CGFloat?
    ) -> VNHumanBodyPoseObservation? {
        // Discard non-human detections (chairs, objects with humanoid silhouettes)
        let humans = results.filter { isHuman($0) }
        guard !humans.isEmpty else { return nil }

        if let anchor = anchorX {
            return humans.min { obsA, obsB in
                let dA = abs((shoulderMidX(obs: obsA) ?? 999) - anchor)
                let dB = abs((shoulderMidX(obs: obsB) ?? 999) - anchor)
                return dA < dB
            }
        }

        return humans.max { obsA, obsB in
            jointCount(obs: obsA) < jointCount(obs: obsB)
        }
    }

    /// Returns true only if the observation looks like an actual seated human.
    private func isHuman(_ obs: VNHumanBodyPoseObservation) -> Bool {
        guard let points = try? obs.recognizedPoints(.all) else { return false }

        // 1. Must have at least one face/head joint — objects don't have faces
        let faceJoints: [VNHumanBodyPoseObservation.JointName] = [
            .nose, .leftEar, .rightEar, .leftEye, .rightEye
        ]
        let hasHead = faceJoints.contains { (points[$0]?.confidence ?? 0) > 0.15 }
        guard hasHead else { return false }

        // 2. Must have both shoulders
        guard (points[.leftShoulder]?.confidence ?? 0) > 0.1,
              (points[.rightShoulder]?.confidence ?? 0) > 0.1
        else { return false }

        // 3. Head must be geometrically above shoulders (Vision Y: 0=bottom, 1=top)
        let headY = faceJoints.compactMap { points[$0].map { $0.location.y } }.max() ?? 0
        let shoulderY = max(
            points[.leftShoulder]?.location.y ?? 0,
            points[.rightShoulder]?.location.y ?? 0
        )
        guard headY > shoulderY else { return false }

        // 4. Minimum total joints — random object mappings produce very few points
        guard jointCount(obs: obs) >= 5 else { return false }

        return true
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
