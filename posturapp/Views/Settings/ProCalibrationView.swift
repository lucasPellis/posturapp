import SwiftUI
import Vision

struct ProCalibrationView: View {

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

            Group {
                switch phase {
                case .intro:    introPage
                case .good:     capturePage(label: "good")
                case .bad:      capturePage(label: "bad")
                case .complete: completePage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 500, height: 460)
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
        .padding(.vertical, 16)
    }

    private var headerSubtitle: String {
        switch phase {
        case .intro: return "Train posturapp with your actual poses"
        case .good: return "Step 1 of 2 — Good posture samples"
        case .bad: return "Step 2 of 2 — Bad posture samples"
        case .complete: return "All done!"
        }
    }

    // MARK: - Intro

    private var introPage: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 52))
                .foregroundStyle(.blue.gradient)

            VStack(spacing: 10) {
                Text("Teach posturapp YOUR body")
                    .font(.system(size: 20, weight: .bold))
                Text("Instead of guessing thresholds, you'll record real examples of how YOU sit — both good and bad. posturapp learns the difference and detects YOUR specific bad habits.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                stepRow(number: "1", text: "Record 2–5 examples of good posture")
                stepRow(number: "2", text: "Record 2–5 examples of bad posture")
                stepRow(number: "3", text: "posturapp activates your personal model")
            }
            .padding(16)
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
        .padding(32)
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

    // MARK: - Capture page (good & bad)

    private func capturePage(label: String) -> some View {
        let isGood = label == "good"
        let prompts = isGood ? goodPrompts : badPrompts
        let samples = isGood ? working.goodSamples : working.badSamples
        let accentColor: Color = isGood ? .green : .red
        let canContinue = samples.count >= 2
        let currentPrompt = prompts[min(promptIndex, prompts.count - 1)]

        return VStack(spacing: 20) {

            // Progress pills
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { i in
                    Capsule()
                        .fill(i < samples.count ? accentColor : Color(NSColor.separatorColor))
                        .frame(width: 32, height: 6)
                }
            }

            // Prompt card
            VStack(spacing: 10) {
                Text(isGood ? "✅ Good Posture" : "💀 Bad Posture")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(accentColor)
                    .textCase(.uppercase)
                    .tracking(1)

                Text(currentPrompt)
                    .font(.system(size: 18, weight: .bold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(accentColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Feedback
            if let fb = feedback {
                HStack(spacing: 6) {
                    Image(systemName: fb.isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    Text(fb.text)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(fb.isSuccess ? accentColor : .orange)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "camera.fill")
                        .foregroundColor(.secondary)
                    Text("Make sure your body is visible in the camera")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Sample count
            Text("\(samples.count) sample\(samples.count == 1 ? "" : "s") captured")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(samples.count >= 2 ? accentColor : .secondary)

            Spacer()

            // Actions
            HStack(spacing: 12) {
                if promptIndex < prompts.count - 1 && samples.count < 5 {
                    Button("Skip prompt") {
                        promptIndex += 1
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.secondary)
                }

                Button("Capture Sample") {
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
        .padding(28)
        .animation(.easeInOut(duration: 0.2), value: feedback?.text)
    }

    // MARK: - Complete

    private var completePage: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green.gradient)

            VStack(spacing: 8) {
                Text("Pro model active!")
                    .font(.system(size: 22, weight: .bold))
                Text("posturapp will now use your \(working.goodSamples.count) good + \(working.badSamples.count) bad posture samples to detect issues. The more varied your samples, the better it gets.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 8) {
                infoRow(icon: "checkmark.circle.fill", color: .green,
                        text: "\(working.goodSamples.count) good posture samples captured")
                infoRow(icon: "xmark.circle.fill", color: .red,
                        text: "\(working.badSamples.count) bad posture samples captured")
                infoRow(icon: "arrow.clockwise", color: .blue,
                        text: "Re-run anytime to improve accuracy")
            }
            .padding(16)
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
            Image(systemName: icon)
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 13))
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
            guard working.goodSamples.count < 5 else {
                showFeedback(.failure("Maximum 5 samples reached"))
                return
            }
            working.goodSamples.append(features)
        } else {
            guard working.badSamples.count < 5 else {
                showFeedback(.failure("Maximum 5 samples reached"))
                return
            }
            working.badSamples.append(features)
        }

        let count = isGood ? working.goodSamples.count : working.badSamples.count
        showFeedback(.success("Sample \(count) captured!"))

        // Advance to next prompt automatically
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
