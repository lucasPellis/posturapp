import SwiftUI

struct MenuBarView: View {

    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var poseDetector: PoseDetector
    @EnvironmentObject var postureAnalyzer: PostureAnalyzer

    @State private var showCalibrationSuccess = false
    @State private var calibrationFailed = false

    var body: some View {
        VStack(spacing: 0) {
            CameraView()
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(10)

            Divider()

            statusBar
                .frame(height: 56)
                .padding(.horizontal, 12)

            if postureAnalyzer.postureState == .needsCalibration || postureAnalyzer.baseline != nil {
                Divider()
                calibrationBar
                    .frame(height: 48)
                    .padding(.horizontal, 12)
            }
        }
        .frame(width: 320)
        .background(.black)
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .shadow(color: statusColor.opacity(0.6), radius: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)

                if postureAnalyzer.consecutiveBadSeconds > 3 {
                    Text("Bad for \(Int(postureAnalyzer.consecutiveBadSeconds))s")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            if !poseDetector.bodyDetected {
                Image(systemName: "person.slash")
                    .foregroundColor(.gray)
                    .font(.system(size: 14))
            }
        }
    }

    // MARK: - Calibration Bar

    private var calibrationBar: some View {
        HStack {
            if postureAnalyzer.postureState == .needsCalibration {
                Image(systemName: "person.badge.plus")
                    .foregroundColor(.yellow)
                Text("Sit up straight, then calibrate")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            } else if showCalibrationSuccess {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Calibrated!")
                    .font(.system(size: 11))
                    .foregroundColor(.green)
            } else if calibrationFailed {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("No body detected — try again")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
            } else if postureAnalyzer.baseline != nil {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.gray)
                    .font(.system(size: 11))
                Text("Calibrated")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }

            Spacer()

            Button(action: calibrate) {
                Text(postureAnalyzer.baseline == nil ? "Calibrate" : "Recalibrate")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.8))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Actions

    private func calibrate() {
        showCalibrationSuccess = false
        calibrationFailed = false

        let success = postureAnalyzer.calibrate(joints: poseDetector.joints)

        if success {
            showCalibrationSuccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                showCalibrationSuccess = false
            }
        } else {
            calibrationFailed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                calibrationFailed = false
            }
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch postureAnalyzer.postureState {
        case .unknown, .needsCalibration: return .gray
        case .good: return .green
        case .bad: return .red
        }
    }

    private var statusTitle: String {
        switch postureAnalyzer.postureState {
        case .unknown: return "No body detected"
        case .needsCalibration: return "Calibration needed"
        case .good: return "Good posture"
        case .bad(let reason): return reason
        }
    }
}
