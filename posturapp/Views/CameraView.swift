import SwiftUI

struct CameraView: View {

    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var poseDetector: PoseDetector
    @EnvironmentObject var postureAnalyzer: PostureAnalyzer

    @State private var pulsing = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                cameraLayer
                SkeletonOverlayView(
                    joints: poseDetector.joints,
                    viewSize: geometry.size,
                    isPostureBad: postureAnalyzer.postureState.isBad
                )
                if postureAnalyzer.postureState.isBad {
                    badPostureOverlay
                }
            }
        }
        .onChange(of: postureAnalyzer.postureState.isBad) { _, isBad in
            pulsing = isBad
        }
    }

    // Pulsing red vignette overlay
    private var badPostureOverlay: some View {
        RoundedRectangle(cornerRadius: 0)
            .strokeBorder(
                Color.red.opacity(pulsing ? 0.85 : 0.2),
                lineWidth: 6
            )
            .animation(
                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                value: pulsing
            )
            .onAppear { pulsing = true }
            .overlay {
                // Corner warning indicators
                VStack {
                    HStack {
                        warningIcon
                        Spacer()
                        warningIcon
                    }
                    Spacer()
                }
                .padding(10)
            }
    }

    private var warningIcon: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundColor(.red)
            .font(.system(size: 14, weight: .bold))
            .opacity(pulsing ? 1.0 : 0.3)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulsing)
    }

    @ViewBuilder
    private var cameraLayer: some View {
        if cameraManager.permissionDenied {
            Color.black
            VStack(spacing: 8) {
                Image(systemName: "camera.fill.badge.ellipsis")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                Text("Camera access denied")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
        } else if let image = cameraManager.previewImage {
            Image(image, scale: 1, label: Text("Camera"))
                .resizable()
                .scaledToFill()
                .clipped()
        } else {
            Color.black
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
        }
    }
}
