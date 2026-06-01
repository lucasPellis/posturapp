import Vision
import Combine

// MARK: - Baseline

struct PostureBaseline: Codable {
    /// Horizontal distance between ears (grows when leaning toward camera)
    let earWidth: CGFloat
    /// Vertical gap from ears to shoulders (shrinks when slouching)
    let earShoulderGap: CGFloat
    /// Horizontal distance between shoulders (reference for shoulder level check)
    let shoulderWidth: CGFloat

    static func capture(joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) -> PostureBaseline? {
        func pt(_ name: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
            guard let p = joints[name], p.confidence >= 0.25 else { return nil }
            return p.location
        }

        guard
            let leftEar = pt(.leftEar),
            let rightEar = pt(.rightEar),
            let leftShoulder = pt(.leftShoulder),
            let rightShoulder = pt(.rightShoulder)
        else { return nil }

        let earWidth = abs(leftEar.x - rightEar.x)
        let earY = (leftEar.y + rightEar.y) / 2
        let shoulderY = (leftShoulder.y + rightShoulder.y) / 2
        let earShoulderGap = earY - shoulderY
        let shoulderWidth = abs(leftShoulder.x - rightShoulder.x)

        return PostureBaseline(
            earWidth: earWidth,
            earShoulderGap: earShoulderGap,
            shoulderWidth: shoulderWidth
        )
    }

    // MARK: - Persistence

    private static let defaultsKey = "posture.baseline"

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }

    static func load() -> PostureBaseline? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let baseline = try? JSONDecoder().decode(PostureBaseline.self, from: data)
        else { return nil }
        return baseline
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}

// MARK: - State

enum PostureState: Equatable {
    case unknown
    case needsCalibration
    case good
    case bad(reason: String)

    static func == (lhs: PostureState, rhs: PostureState) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown), (.good, .good), (.needsCalibration, .needsCalibration): return true
        case (.bad(let a), .bad(let b)): return a == b
        default: return false
        }
    }

    var isBad: Bool {
        if case .bad = self { return true }
        return false
    }

    var badReason: String? {
        if case .bad(let r) = self { return r }
        return nil
    }
}

// MARK: - Analyzer

final class PostureAnalyzer: ObservableObject {

    @Published var postureState: PostureState = .needsCalibration
    @Published var consecutiveBadSeconds: Double = 0
    @Published var shouldAlert = false
    @Published var baseline: PostureBaseline?

    var leanForwardTolerance: CGFloat = 0.20
    var slouchTolerance: CGFloat = 0.25
    private let shoulderAsymmetryThreshold: CGFloat = 0.05

    private let minimumConfidence: Float = 0.25
    private var badPostureStartTime: Date?
    private var lastAlertTime: Date?
    var alertThreshold: TimeInterval = 30
    var alertCooldown: TimeInterval = 30

    init() {
        baseline = PostureBaseline.load()
        postureState = baseline == nil ? .needsCalibration : .unknown
    }

    // MARK: - Calibration

    /// Call this when the user clicks "Calibrate" while sitting in good posture
    func calibrate(joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) -> Bool {
        guard let captured = PostureBaseline.capture(joints: joints) else { return false }
        baseline = captured
        captured.save()
        postureState = .unknown
        return true
    }

    func clearCalibration() {
        baseline = nil
        PostureBaseline.clear()
        postureState = .needsCalibration
    }

    // MARK: - Analysis

    func analyze(joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) {
        guard !joints.isEmpty else {
            postureState = .unknown
            resetBadTimer()
            return
        }

        guard let baseline else {
            postureState = .needsCalibration
            return
        }

        if let issue = evaluatePosture(joints: joints, baseline: baseline) {
            postureState = .bad(reason: issue)
            handleBadPosture(reason: issue)
        } else {
            postureState = .good
            resetBadTimer()
        }
    }

    func resetAlert() {
        shouldAlert = false
        lastAlertTime = Date()
    }

    // MARK: - Heuristics (all relative to personal baseline)

    private func evaluatePosture(
        joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint],
        baseline: PostureBaseline
    ) -> String? {

        // 1. Leaning toward screen: ear width grows relative to baseline
        if let leftEar = point(joints, .leftEar),
           let rightEar = point(joints, .rightEar) {
            let earWidth = abs(leftEar.x - rightEar.x)
            if earWidth > baseline.earWidth * (1 + leanForwardTolerance) {
                return "You're leaning too close to the screen"
            }
        }

        // 2. Slouching: ear-to-shoulder gap shrinks relative to baseline
        let earY = averageY(joints, .leftEar, .rightEar)
        let shoulderY = averageY(joints, .leftShoulder, .rightShoulder)

        if let earY, let shoulderY {
            let currentGap = earY - shoulderY
            if currentGap < baseline.earShoulderGap * (1 - slouchTolerance) {
                return "You appear to be slouching"
            }
        }

        // 3. Shoulder asymmetry (absolute — it's inherently relative)
        if let leftShoulder = point(joints, .leftShoulder),
           let rightShoulder = point(joints, .rightShoulder),
           abs(leftShoulder.y - rightShoulder.y) > shoulderAsymmetryThreshold {
            return "Your shoulders are uneven"
        }

        return nil
    }

    // MARK: - Timer

    private func handleBadPosture(reason: String) {
        if badPostureStartTime == nil { badPostureStartTime = Date() }
        guard let start = badPostureStartTime else { return }
        consecutiveBadSeconds = Date().timeIntervalSince(start)

        guard consecutiveBadSeconds >= alertThreshold else { return }
        let canAlert = lastAlertTime.map { Date().timeIntervalSince($0) >= alertCooldown } ?? true
        if canAlert && !shouldAlert { shouldAlert = true }
    }

    private func resetBadTimer() {
        badPostureStartTime = nil
        consecutiveBadSeconds = 0
        shouldAlert = false
    }

    // MARK: - Helpers

    private func point(
        _ joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint],
        _ name: VNHumanBodyPoseObservation.JointName
    ) -> CGPoint? {
        guard let p = joints[name], p.confidence >= minimumConfidence else { return nil }
        return p.location
    }

    private func averageY(
        _ joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint],
        _ nameA: VNHumanBodyPoseObservation.JointName,
        _ nameB: VNHumanBodyPoseObservation.JointName
    ) -> CGFloat? {
        let a = point(joints, nameA)?.y
        let b = point(joints, nameB)?.y
        switch (a, b) {
        case (.some(let x), .some(let y)): return (x + y) / 2
        case (.some(let x), nil): return x
        case (nil, .some(let y)): return y
        default: return nil
        }
    }
}
