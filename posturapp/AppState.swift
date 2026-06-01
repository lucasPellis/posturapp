import Combine
@preconcurrency import Vision

final class AppState: ObservableObject {

    let cameraManager = CameraManager()
    let poseDetector = PoseDetector()
    let postureAnalyzer = PostureAnalyzer()
    let notificationManager = NotificationManager()

    private var cancellables = Set<AnyCancellable>()

    init() {
        notificationManager.requestAuthorization()

        cameraManager.onSampleBuffer = { [weak poseDetector] buffer in
            poseDetector?.process(sampleBuffer: buffer)
        }

        poseDetector.$joints
            .receive(on: DispatchQueue.main)
            .sink { [weak postureAnalyzer] joints in
                postureAnalyzer?.analyze(joints: joints)
            }
            .store(in: &cancellables)

        postureAnalyzer.$shouldAlert
            .receive(on: DispatchQueue.main)
            .sink { [weak self] shouldAlert in
                guard let self else { return }
                if shouldAlert, let reason = self.postureAnalyzer.postureState.badReason {
                    self.notificationManager.scheduleAlert(reason: reason)
                    self.postureAnalyzer.resetAlert()
                }
            }
            .store(in: &cancellables)

        cameraManager.start()
    }
}
