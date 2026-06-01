import SwiftUI
import Vision

struct ProCalibrationView: View {

    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var poseDetector: PoseDetector
    @EnvironmentObject var postureAnalyzer: PostureAnalyzer
    @Environment(\.dismiss) private var dismiss

    @State private var phase: Phase = .intro
    @State private var working = ProCalibrationBaseline()
    @State private var feedback: Feedback? = nil
    @State private var feedbackTask: Task<Void, Never>? = nil

    enum Phase { case intro, capturing, complete }

    private enum Feedback {
        case good(String)
        case bad(String)
        case error(String)

        var text: String {
            switch self { case .good(let s), .bad(let s), .error(let s): return s }
        }
        var color: Color {
            switch self {
            case .good:  return .green
            case .bad:   return .red
            case .error: return .orange
            }
        }
        var icon: String {
            switch self {
            case .good:  return "checkmark.circle.fill"
            case .bad:   return "xmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            }
        }
    }

    private var canFinish: Bool {
        working.goodSamples.count >= 2 && working.badSamples.count >= 2
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if phase != .complete {
                cameraPreview
                Divider()
            }

            Group {
                switch phase {
                case .intro:     introPage
                case .capturing: capturePage
                case .complete:  completePage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 520, height: phase == .complete ? 440 : 640)
        .animation(.easeInOut(duration: 0.25), value: phase)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Pro Calibration")
                    .font(.system(size: 15, weight: .bold))
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Cancel") { dismiss() }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private var headerSubtitle: String {
        switch phase {
        case .intro:     return "Train posturapp with your actual poses"
        case .capturing: return "Label each pose as good or bad"
        case .complete:  return "All done!"
        }
    }

    // MARK: - Camera preview

    private var cameraPreview: some View {
        GeometryReader { geo in
            ZStack {
                Color.black

                if let img = cameraManager.previewImage {
                    Image(img, scale: 1, label: Text("Camera"))
                        .resizable()
                        .scaledToFill()
                        .clipped()
                } else {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }

                SkeletonOverlayView(
                    joints: poseDetector.joints,
                    viewSize: geo.size,
                    isPostureBad: false
                )

                if !poseDetector.bodyDetected {
                    VStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "person.slash")
                            Text("No body detected — move into frame")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.6))
                        .clipShape(Capsule())
                        .padding(.bottom, 10)
                    }
                }
            }
        }
        .frame(height: 210)
    }

    // MARK: - Intro

    private var introPage: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("Teach posturapp YOUR body")
                    .font(.system(size: 17, weight: .bold))
                Text("Get into a posture and label it. Alternate between good and bad as many times as you want — the more varied, the better.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                stepRow(number: "1", text: "Sit in any posture — good or bad")
                stepRow(number: "2", text: "Click the matching button to label it")
                stepRow(number: "3", text: "Repeat with at least 2 good + 2 bad")
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button("Start") {
                working = ProCalibrationBaseline()
                phase = .capturing
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }

    private func stepRow(number: String, text: String) -> some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.system(size: 12, weight: .bold))
                .frame(width: 22, height: 22)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .clipShape(Circle())
            Text(text)
                .font(.system(size: 13))
        }
    }

    // MARK: - Capture

    private var capturePage: some View {
        VStack(spacing: 16) {

            // Counters
            HStack(spacing: 20) {
                sampleCounter(
                    count: working.goodSamples.count,
                    label: "Good",
                    color: .green,
                    icon: "checkmark.circle.fill"
                )
                Divider().frame(height: 36)
                sampleCounter(
                    count: working.badSamples.count,
                    label: "Bad",
                    color: .red,
                    icon: "xmark.circle.fill"
                )
            }
            .padding(.horizontal, 28)
            .padding(.top, 4)

            // Feedback
            Group {
                if let fb = feedback {
                    HStack(spacing: 6) {
                        Image(systemName: fb.icon)
                        Text(fb.text)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(fb.color)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    Text("Adopt a posture and click the matching button")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 22)

            Spacer()

            // Capture buttons
            HStack(spacing: 14) {
                captureButton(
                    title: "Good Posture",
                    subtitle: "Sitting well",
                    icon: "checkmark.circle.fill",
                    color: .green
                ) {
                    capture(isGood: true)
                }

                captureButton(
                    title: "Bad Posture",
                    subtitle: "Slouching / leaning",
                    icon: "xmark.circle.fill",
                    color: .red
                ) {
                    capture(isGood: false)
                }
            }
            .padding(.horizontal, 28)

            // Finish
            if canFinish {
                Button("Finish & Save") {
                    postureAnalyzer.saveProCalibration(working)
                    phase = .complete
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                let goodLeft = max(0, 2 - working.goodSamples.count)
                let badLeft  = max(0, 2 - working.badSamples.count)
                Text(remainingHint(goodLeft: goodLeft, badLeft: badLeft))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 16)
        }
        .animation(.easeInOut(duration: 0.2), value: canFinish)
        .animation(.easeInOut(duration: 0.15), value: feedback?.text)
    }

    private func captureButton(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(color)
                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(color.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(color.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!poseDetector.bodyDetected)
    }

    private func sampleCounter(count: Int, label: String, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(count >= 2 ? color : .secondary)
                .font(.system(size: 18))
            VStack(alignment: .leading, spacing: 1) {
                Text("\(count)")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(count >= 2 ? color : .secondary)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func remainingHint(goodLeft: Int, badLeft: Int) -> String {
        switch (goodLeft, badLeft) {
        case (0, 0): return ""
        case (let g, 0) where g > 0: return "Need \(g) more good sample\(g > 1 ? "s" : "")"
        case (0, let b) where b > 0: return "Need \(b) more bad sample\(b > 1 ? "s" : "")"
        default: return "Need \(goodLeft) more good + \(badLeft) more bad"
        }
    }

    // MARK: - Complete

    private var completePage: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green.gradient)

            VStack(spacing: 8) {
                Text("Pro model active!")
                    .font(.system(size: 20, weight: .bold))
                Text("posturapp will now use your \(working.goodSamples.count) good + \(working.badSamples.count) bad samples to detect issues. The more varied the samples, the better it gets.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 8) {
                infoRow(icon: "checkmark.circle.fill", color: .green,
                        text: "\(working.goodSamples.count) good posture samples")
                infoRow(icon: "xmark.circle.fill", color: .red,
                        text: "\(working.badSamples.count) bad posture samples")
                infoRow(icon: "arrow.clockwise", color: .blue,
                        text: "Re-run anytime to improve accuracy")
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(32)
    }

    private func infoRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(color)
            Text(text).font(.system(size: 13))
            Spacer()
        }
    }

    // MARK: - Capture logic

    private func capture(isGood: Bool) {
        feedbackTask?.cancel()
        guard let features = postureAnalyzer.extractFeatures(joints: poseDetector.joints) else {
            showFeedback(.error("No body detected — try again"))
            return
        }

        if isGood {
            guard working.goodSamples.count < 10 else { return }
            working.goodSamples.append(features)
            showFeedback(.good("Good posture captured (\(working.goodSamples.count) total)"))
        } else {
            guard working.badSamples.count < 10 else { return }
            working.badSamples.append(features)
            showFeedback(.bad("Bad posture captured (\(working.badSamples.count) total)"))
        }
    }

    private func showFeedback(_ fb: Feedback) {
        withAnimation { feedback = fb }
        feedbackTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation { feedback = nil }
        }
    }
}
