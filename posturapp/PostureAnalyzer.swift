import Vision
import Combine

// MARK: - Pro Calibration

struct ProCalibrationBaseline: Codable {

    var goodSamples: [[Double]] = []
    var badSamples: [[Double]] = []

    var isComplete: Bool { goodSamples.count >= 2 && badSamples.count >= 2 }

    var goodCentroid: [Double] { centroid(of: goodSamples) }
    var badCentroid: [Double] { centroid(of: badSamples) }

    private func centroid(of samples: [[Double]]) -> [Double] {
        guard !samples.isEmpty else { return Array(repeating: 0, count: 4) }
        let count = Double(samples.count)
        return (0..<samples[0].count).map { i in
            samples.map { $0[i] }.reduce(0, +) / count
        }
    }

    private static let defaultsKey = "posture.proBaseline"

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }

    static func load() -> ProCalibrationBaseline? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let b = try? JSONDecoder().decode(ProCalibrationBaseline.self, from: data),
              b.isComplete
        else { return nil }
        return b
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}

// MARK: - Basic Baseline

struct PostureBaseline: Codable {
    /// Horizontal distance between ears (grows when leaning toward camera)
    let earWidth: CGFloat
    /// Vertical gap from ears to shoulders (shrinks when slouching)
    let earShoulderGap: CGFloat
    /// Horizontal distance between shoulders (reference for shoulder level check)
    let shoulderWidth: CGFloat
    /// Normalized X of shoulder midpoint — used to lock onto the right person
    let shoulderMidX: CGFloat

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
        let shoulderMidX = (leftShoulder.x + rightShoulder.x) / 2

        return PostureBaseline(
            earWidth: earWidth,
            earShoulderGap: earShoulderGap,
            shoulderWidth: shoulderWidth,
            shoulderMidX: shoulderMidX
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
    @Published var proBaseline: ProCalibrationBaseline?

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
        proBaseline = ProCalibrationBaseline.load()
        postureState = (baseline == nil && proBaseline == nil) ? .needsCalibration : .unknown
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
        if proBaseline == nil { postureState = .needsCalibration }
    }

    // MARK: - Pro Calibration

    /// Extracts a 4-element feature vector normalized by shoulder width.
    func extractFeatures(joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) -> [Double]? {
        func pt(_ name: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
            guard let p = joints[name], p.confidence >= 0.15 else { return nil }
            return p.location
        }
        guard
            let leftShoulder = pt(.leftShoulder),
            let rightShoulder = pt(.rightShoulder),
            let leftEar = pt(.leftEar),
            let rightEar = pt(.rightEar)
        else { return nil }

        let shoulderWidth = abs(rightShoulder.x - leftShoulder.x)
        guard shoulderWidth > 0.01 else { return nil }

        let earWidth = abs(rightEar.x - leftEar.x)
        let earMidY = (leftEar.y + rightEar.y) / 2
        let shoulderMidY = (leftShoulder.y + rightShoulder.y) / 2
        let earShoulderGap = earMidY - shoulderMidY
        let shoulderAsymmetry = abs(leftShoulder.y - rightShoulder.y)
        let earMidX = (leftEar.x + rightEar.x) / 2
        let shoulderMidX = (leftShoulder.x + rightShoulder.x) / 2
        let lateralLean = earMidX - shoulderMidX

        return [
            Double(earWidth / shoulderWidth),
            Double(earShoulderGap / shoulderWidth),
            Double(shoulderAsymmetry / shoulderWidth),
            Double(lateralLean / shoulderWidth),
        ]
    }

    func saveProCalibration(_ pro: ProCalibrationBaseline) {
        proBaseline = pro
        pro.save()
        if postureState == .needsCalibration { postureState = .unknown }
    }

    func clearProCalibration() {
        proBaseline = nil
        ProCalibrationBaseline.clear()
        if baseline == nil { postureState = .needsCalibration }
    }

    // MARK: - Analysis

    func analyze(joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) {
        guard !joints.isEmpty else {
            postureState = .unknown
            resetBadTimer()
            return
        }

        // Pro baseline takes priority over basic baseline
        if let pro = proBaseline {
            if let features = extractFeatures(joints: joints),
               let issue = classifyWithPro(features: features, baseline: pro) {
                postureState = .bad(reason: issue)
                handleBadPosture(reason: issue)
            } else {
                postureState = .good
                resetBadTimer()
            }
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

    // MARK: - Pro Classifier (centroid distance)

    private func classifyWithPro(features: [Double], baseline: ProCalibrationBaseline) -> String? {
        let good = baseline.goodCentroid
        let bad = baseline.badCentroid
        let distGood = euclidean(features, good)
        let distBad = euclidean(features, bad)

        // Require bad to be meaningfully closer to avoid false positives
        guard distBad < distGood * 0.85 else { return nil }

        // Identify the most deviated feature from good centroid to pick a reason
        let deltas = zip(features, good).map { abs($0 - $1) }
        let worst = deltas.enumerated().max(by: { $0.element < $1.element })?.offset

        switch worst {
        case 0: return "You're leaning too close to the screen"
        case 1: return "You appear to be slouching"
        case 2: return "Your shoulders are uneven"
        case 3: return "You're leaning to the side"
        default: return "Bad posture detected"
        }
    }

    private func euclidean(_ a: [Double], _ b: [Double]) -> Double {
        zip(a, b).map { pow($0 - $1, 2) }.reduce(0, +).squareRoot()
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
