import SwiftUI

struct MenuBarView: View {

    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var poseDetector: PoseDetector
    @EnvironmentObject var postureAnalyzer: PostureAnalyzer
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: AppSettings

    @State private var showCalibrationSuccess = false
    @State private var calibrationFailed = false

    var body: some View {
        VStack(spacing: 0) {
            // Camera / paused view
            Group {
                if appState.isMonitoring {
                    CameraView()
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    pausedView
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(10)

            Divider()

            statusBar.frame(height: 52).padding(.horizontal, 12)

            Divider()

            calibrationBar.frame(height: 40).padding(.horizontal, 12)

            Divider()

            bottomBar.frame(height: 44).padding(.horizontal, 12)
        }
        .frame(width: 320)
        .background(.black)
    }

    // MARK: - Paused

    private var pausedView: some View {
        ZStack {
            Color(white: 0.08)
            VStack(spacing: 10) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.gray)
                Text("Monitoring paused")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
        }
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

            if appState.isMonitoring && !poseDetector.bodyDetected {
                Image(systemName: "person.slash")
                    .foregroundColor(.gray)
                    .font(.system(size: 14))
            }
        }
    }

    // MARK: - Calibration Bar

    private var calibrationBar: some View {
        HStack {
            if showCalibrationSuccess {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                Text("Calibrated!").font(.system(size: 11)).foregroundColor(.green)
            } else if calibrationFailed {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                Text("No body detected — try again").font(.system(size: 11)).foregroundColor(.orange)
            } else if postureAnalyzer.postureState == .needsCalibration {
                Image(systemName: "person.badge.plus").foregroundColor(.yellow)
                Text("Sit straight, then calibrate").font(.system(size: 11)).foregroundColor(.gray)
            } else {
                Image(systemName: "checkmark.seal.fill").foregroundColor(.gray).font(.system(size: 11))
                Text("Calibrated").font(.system(size: 11)).foregroundColor(.gray)
            }

            Spacer()

            Button(postureAnalyzer.baseline == nil ? "Calibrate" : "Recalibrate") {
                calibrate()
            }
            .font(.system(size: 11, weight: .medium))
            .buttonStyle(.borderless)
            .foregroundColor(.blue)
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            // On/Off toggle
            Toggle(isOn: Binding(
                get: { appState.isMonitoring },
                set: { _ in appState.toggleMonitoring() }
            )) {
                HStack(spacing: 6) {
                    Image(systemName: appState.isMonitoring ? "eye.fill" : "eye.slash.fill")
                        .font(.system(size: 12))
                        .foregroundColor(appState.isMonitoring ? .green : .gray)
                    Text(appState.isMonitoring ? "Monitoring" : "Paused")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(appState.isMonitoring ? .white : .gray)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)

            Spacer()

            Button {
                SettingsWindowManager.shared.open(appState: appState)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
        }
    }

    // MARK: - Actions

    private func calibrate() {
        showCalibrationSuccess = false
        calibrationFailed = false
        let success = postureAnalyzer.calibrate(joints: poseDetector.joints)
        if success {
            showCalibrationSuccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { showCalibrationSuccess = false }
        } else {
            calibrationFailed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { calibrationFailed = false }
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        guard appState.isMonitoring else { return .gray }
        switch postureAnalyzer.postureState {
        case .unknown, .needsCalibration: return .gray
        case .good: return .green
        case .bad: return .red
        }
    }

    private var statusTitle: String {
        guard appState.isMonitoring else { return "Paused" }
        switch postureAnalyzer.postureState {
        case .unknown: return "No body detected"
        case .needsCalibration: return "Calibration needed"
        case .good: return "Good posture"
        case .bad(let reason): return reason
        }
    }
}
