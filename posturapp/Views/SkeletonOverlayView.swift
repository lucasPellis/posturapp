import SwiftUI
import Vision

struct SkeletonOverlayView: View {

    let joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]
    let viewSize: CGSize
    let isPostureBad: Bool

    private let connections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        // Head
        (.nose, .neck),
        (.leftEar, .nose),
        (.rightEar, .nose),
        // Torso
        (.neck, .leftShoulder),
        (.neck, .rightShoulder),
        (.leftShoulder, .leftHip),
        (.rightShoulder, .rightHip),
        (.leftHip, .rightHip),
        // Left arm
        (.leftShoulder, .leftElbow),
        (.leftElbow, .leftWrist),
        // Right arm
        (.rightShoulder, .rightElbow),
        (.rightElbow, .rightWrist),
    ]

    var body: some View {
        Canvas { context, size in
            let boneColor: Color = isPostureBad ? .red : .green

            // Draw bones
            for (fromName, toName) in connections {
                guard
                    let from = viewPoint(fromName, in: size),
                    let to = viewPoint(toName, in: size)
                else { continue }

                var path = Path()
                path.move(to: from)
                path.addLine(to: to)
                context.stroke(path, with: .color(boneColor.opacity(0.85)), lineWidth: 2.5)
            }

            // Draw joints
            for (name, _) in joints {
                guard let point = viewPoint(name, in: size) else { continue }
                let rect = CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
                context.fill(Path(ellipseIn: rect), with: .color(.yellow))
            }
        }
    }

    private func viewPoint(_ name: VNHumanBodyPoseObservation.JointName, in size: CGSize) -> CGPoint? {
        guard let point = joints[name], point.confidence > 0.3 else { return nil }
        // Vision: origin bottom-left, y up → SwiftUI: origin top-left, y down
        // Mirror x to match the horizontally flipped camera preview
        return CGPoint(
            x: (1 - point.location.x) * size.width,
            y: (1 - point.location.y) * size.height
        )
    }
}
