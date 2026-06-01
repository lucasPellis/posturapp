import Combine
@preconcurrency import Vision

final class AppState: ObservableObject {

    let cameraManager = CameraManager()
    let poseDetector = PoseDetector()
    let postureAnalyzer = PostureAnalyzer()
    let notificationManager = NotificationManager()
    let statsStore = PostureStatsStore()
    let settings = AppSettings.shared

    @Published var isMonitoring = true

    private var cancellables = Set<AnyCancellable>()

    init() {
        notificationManager.requestAuthorization()

        cameraManager.onSampleBuffer = { [weak poseDetector] buffer in
            poseDetector?.process(sampleBuffer: buffer)
        }

        poseDetector.$joints
            .receive(on: DispatchQueue.main)
            .sink { [weak self] joints in
                guard let self, self.isMonitoring else { return }
                self.postureAnalyzer.analyze(joints: joints)
            }
            .store(in: &cancellables)

        postureAnalyzer.$postureState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.statsStore.record(state: state)
            }
            .store(in: &cancellables)

        postureAnalyzer.$shouldAlert
            .receive(on: DispatchQueue.main)
            .sink { [weak self] shouldAlert in
                guard let self, shouldAlert else { return }
                guard let reason = self.postureAnalyzer.postureState.badReason else { return }
                self.notificationManager.scheduleAlert(
                    reason: reason,
                    settings: self.settings
                )
                self.postureAnalyzer.resetAlert()
            }
            .store(in: &cancellables)

        // Sync settings into analyzer
        settings.$alertThreshold
            .sink { [weak postureAnalyzer] val in postureAnalyzer?.alertThreshold = val }
            .store(in: &cancellables)

        settings.$alertCooldown
            .sink { [weak postureAnalyzer] val in postureAnalyzer?.alertCooldown = val }
            .store(in: &cancellables)

        settings.$leanForwardTolerance
            .sink { [weak postureAnalyzer] val in postureAnalyzer?.leanForwardTolerance = CGFloat(val) }
            .store(in: &cancellables)

        settings.$slouchTolerance
            .sink { [weak postureAnalyzer] val in postureAnalyzer?.slouchTolerance = CGFloat(val) }
            .store(in: &cancellables)

        cameraManager.start()
    }

    func toggleMonitoring() {
        isMonitoring.toggle()
        if isMonitoring {
            cameraManager.start()
        } else {
            cameraManager.stop()
            postureAnalyzer.postureState = .unknown
        }
    }
}
