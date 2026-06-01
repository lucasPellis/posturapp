import SwiftUI
import Vision

struct ProCalibrationView: View {

    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var poseDetector: PoseDetector
    @EnvironmentObject var postureAnalyzer: PostureAnalyzer
    @Environment(\.dismiss) private var dismiss

    @State private var phase: Phase = .intro
    @State private var working = ProCalibrationBaseline()
    @State private var promptIndex = 0
    @State private var feedback: Feedback? = nil
    @State private var feedbackTask: Task<Void, Never>? = nil

    enum Phase { case intro, good, bad, complete }

    private enum Feedback {
        case success(String)
        case failure(String)
        var isSuccess: Bool { if case .success = self { return true }; return false }
        var text: String { switch self { case .success(let s), .failure(let s): return s } }
    }

    private let goodPrompts = [
        "Sit up straight, shoulders even and relaxed",
        "Same position — look slightly to the left",
        "Same position — look slightly to the right",
        "Lean back just a little into your chair",
        "Head perfectly centered, chin slightly tucked",
    ]

    private let badPrompts = [
        "Slouch forward — let your back curve",
        "Lean your head toward the screen",
        "Tilt your body to one side",
        "Let your shoulders sag and drop forward",
        "Crane your neck toward the screen",
    ]

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
                case .intro:    introPage
                case .good:     capturePage(isGood: true)
                case .bad:      capturePage(isGood: false)
                case .complete: completePage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 520, height: phase == .complete ? 440 : 660)
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
        case .intro:    return "Train posturapp with your actual poses"
        case .good:     return "Step 1 of 2 — Good posture samples"
        case .bad:      return "Step 2 of 2 — Bad posture samples"
        case .complete: return "All done!"
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

                // Body detection indicator
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
                Text("Record real examples of how YOU sit — good and bad. posturapp learns the difference and detects YOUR specific habits.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                stepRow(number: "1", text: "Record 2–5 examples of good posture")
                stepRow(number: "2", text: "Record 2–5 examples of bad posture")
                stepRow(number: "3", text: "posturapp activates your personal model")
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button("Start Pro Calibration") {
                working = ProCalibrationBaseline()
                promptIndex = 0
                phase = .good
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

    // MARK: - Capture page

    private func capturePage(isGood: Bool) -> some View {
        let prompts = isGood ? goodPrompts : badPrompts
        let samples = isGood ? working.goodSamples : working.badSamples
        let accentColor: Color = isGood ? .green : .red
        let canContinue = samples.count >= 2
        let currentPrompt = prompts[min(promptIndex, prompts.count - 1)]

        return VStack(spacing: 14) {

            // Progress pills
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { i in
                    Capsule()
                        .fill(i < samples.count ? accentColor : Color(NSColor.separatorColor))
                        .frame(width: 36, height: 6)
                }
            }

            // Prompt card
            VStack(spacing: 6) {
                Text(isGood ? "✅ Good Posture" : "💀 Bad Posture")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(accentColor)
                    .textCase(.uppercase)
                    .tracking(1)

                Text(currentPrompt)
                    .font(.system(size: 16, weight: .bold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(accentColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Feedback / hint
            Group {
                if let fb = feedback {
                    HStack(spacing: 6) {
                        Image(systemName: fb.isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        Text(fb.text)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(fb.isSuccess ? accentColor : .orange)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    Text("\(samples.count) sample\(samples.count == 1 ? "" : "s") captured")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(samples.count >= 2 ? accentColor : .secondary)
                }
            }
            .frame(height: 22)

            Spacer()

            // Actions
            HStack(spacing: 10) {
                if promptIndex < prompts.count - 1 && samples.count < 5 {
                    Button("Skip") {
                        promptIndex += 1
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.secondary)
                }

                Button("Capture") {
                    captureCurrentSample(isGood: isGood)
                }
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
                .controlSize(.large)

                if canContinue {
                    Button(isGood ? "Continue →" : "Finish & Save") {
                        if isGood {
                            promptIndex = 0
                            phase = .bad
                        } else {
                            postureAnalyzer.saveProCalibration(working)
                            phase = .complete
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .animation(.easeInOut(duration: 0.2), value: feedback?.text)
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
                Text("posturapp will now use your \(working.goodSamples.count) good + \(working.badSamples.count) bad samples to detect issues. The more varied your samples, the better it gets.")
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

    private func captureCurrentSample(isGood: Bool) {
        feedbackTask?.cancel()
        guard let features = postureAnalyzer.extractFeatures(joints: poseDetector.joints) else {
            showFeedback(.failure("No body detected — try again"))
            return
        }

        if isGood {
            guard working.goodSamples.count < 5 else { return }
            working.goodSamples.append(features)
        } else {
            guard working.badSamples.count < 5 else { return }
            working.badSamples.append(features)
        }

        let count = isGood ? working.goodSamples.count : working.badSamples.count
        showFeedback(.success("Sample \(count) captured!"))

        let prompts = isGood ? goodPrompts : badPrompts
        if promptIndex < prompts.count - 1 {
            promptIndex += 1
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
