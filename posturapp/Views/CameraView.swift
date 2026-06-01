import SwiftUI

struct CameraView: View {

    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var poseDetector: PoseDetector
    @EnvironmentObject var postureAnalyzer: PostureAnalyzer

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                cameraLayer
                SkeletonOverlayView(
                    joints: poseDetector.joints,
                    viewSize: geometry.size,
                    isPostureBad: postureAnalyzer.postureState.isBad
                )
            }
        }
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
                .scaleEffect(x: -1) // Mirror horizontally like a selfie camera
        } else {
            Color.black
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
        }
    }
}
