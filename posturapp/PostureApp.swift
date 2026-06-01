import SwiftUI

@main
struct PostureApp: App {

    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("PostureApp", systemImage: menuBarIcon) {
            MenuBarView()
                .environmentObject(appState.cameraManager)
                .environmentObject(appState.poseDetector)
                .environmentObject(appState.postureAnalyzer)
                .environmentObject(appState.settings)
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarIcon: String {
        if !appState.isMonitoring { return "eye.slash" }
        switch appState.postureAnalyzer.postureState {
        case .bad: return "exclamationmark.triangle.fill"
        case .needsCalibration: return "person.badge.plus"
        default: return "figure.stand"
        }
    }
}
