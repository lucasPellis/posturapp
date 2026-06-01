import SwiftUI

struct GeneralSettingsView: View {

    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var postureAnalyzer: PostureAnalyzer
    @EnvironmentObject var poseDetector: PoseDetector

    @State private var calibrationMessage: String? = nil
    @State private var showProCalibration = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // MARK: Calibration
                settingsSection("Calibration") {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Personal baseline")
                                .font(.headline)
                            Text("Sit in your ideal posture, then click Calibrate. Your measurements are saved and used to detect deviations.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            if let msg = calibrationMessage {
                                Text(msg)
                                    .font(.caption)
                                    .foregroundColor(msg.contains("✓") ? .green : .orange)
                                    .padding(.top, 2)
                            }
                        }

                        Spacer()

                        VStack(spacing: 8) {
                            Button(postureAnalyzer.baseline == nil ? "Calibrate" : "Recalibrate") {
                                let ok = postureAnalyzer.calibrate(joints: poseDetector.joints)
                                calibrationMessage = ok ? "✓ Calibrated successfully" : "⚠ No body detected — try again"
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { calibrationMessage = nil }
                            }
                            .buttonStyle(.borderedProminent)

                            if postureAnalyzer.baseline != nil {
                                Button("Clear") {
                                    postureAnalyzer.clearCalibration()
                                    calibrationMessage = "Calibration cleared"
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { calibrationMessage = nil }
                                }
                                .buttonStyle(.bordered)
                                .foregroundColor(.red)
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // MARK: Pro Calibration
                settingsSection("Pro Calibration") {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text("Personal posture model")
                                    .font(.headline)
                                Text("PRO")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.purple.opacity(0.2))
                                    .foregroundColor(.purple)
                                    .clipShape(Capsule())
                            }
                            Text("Record examples of your good and bad postures. posturapp trains a personal model and detects YOUR specific habits — much more accurate than generic thresholds.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            if let pro = postureAnalyzer.proBaseline {
                                HStack(spacing: 12) {
                                    Label("\(pro.goodSamples.count) good", systemImage: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Label("\(pro.badSamples.count) bad", systemImage: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .font(.caption)
                                .padding(.top, 2)
                            } else {
                                Text("Not configured — basic calibration is active")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .italic()
                                    .padding(.top, 2)
                            }
                        }

                        Spacer()

                        VStack(spacing: 8) {
                            Button(postureAnalyzer.proBaseline == nil ? "Set Up" : "Re-train") {
                                showProCalibration = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.purple)

                            if postureAnalyzer.proBaseline != nil {
                                Button("Clear") {
                                    postureAnalyzer.clearProCalibration()
                                }
                                .buttonStyle(.bordered)
                                .foregroundColor(.red)
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .sheet(isPresented: $showProCalibration) {
                    ProCalibrationView()
                        .environmentObject(poseDetector)
                        .environmentObject(postureAnalyzer)
                }

                // MARK: Alert timing
                settingsSection("Alert Timing") {
                    VStack(spacing: 16) {
                        sliderRow(
                            label: "Alert after",
                            value: $settings.alertThreshold,
                            range: 10...120,
                            step: 5,
                            format: { "\(Int($0))s of bad posture" }
                        )
                        Divider()
                        sliderRow(
                            label: "Re-alert after",
                            value: $settings.alertCooldown,
                            range: 15...300,
                            step: 15,
                            format: { "\(Int($0))s cooldown" }
                        )
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // MARK: Detection sensitivity
                settingsSection("Detection Sensitivity") {
                    VStack(spacing: 16) {
                        sliderRow(
                            label: "Lean forward",
                            value: $settings.leanForwardTolerance,
                            range: 0.05...0.50,
                            step: 0.05,
                            format: { "triggers at \(Int($0 * 100))% deviation" }
                        )
                        Divider()
                        sliderRow(
                            label: "Slouch",
                            value: $settings.slouchTolerance,
                            range: 0.05...0.50,
                            step: 0.05,
                            format: { "triggers at \(Int($0 * 100))% deviation" }
                        )
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // MARK: Notifications & display
                settingsSection("Notifications & Display") {
                    VStack(spacing: 0) {
                        toggleRow("Show skeleton overlay", icon: "person.fill.viewfinder", binding: $settings.showSkeleton)
                        Divider().padding(.leading, 44)
                        toggleRow("Full-screen alert overlay", icon: "exclamationmark.square.fill", binding: $settings.enableFullScreenOverlay)
                        Divider().padding(.leading, 44)
                        toggleRow("System notifications", icon: "bell.badge.fill", binding: $settings.enableNotifications)
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Spacer(minLength: 16)
            }
            .padding()
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            content()
        }
    }

    @ViewBuilder
    private func sliderRow(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        format: (Double) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 13))
                Spacer()
                Text(format(value.wrappedValue))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.accentColor)
                    .monospacedDigit()
            }
            Slider(value: value, in: range, step: step)
        }
    }

    @ViewBuilder
    private func toggleRow(_ label: String, icon: String, binding: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(.accentColor)
                .padding(.leading, 12)
            Text(label)
                .font(.system(size: 13))
            Spacer()
            Toggle("", isOn: binding)
                .labelsHidden()
                .padding(.trailing, 12)
        }
        .frame(height: 44)
    }
}
