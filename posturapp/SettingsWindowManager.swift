import AppKit
import SwiftUI

final class SettingsWindowManager {

    static let shared = SettingsWindowManager()
    private var window: NSWindow?

    private init() {}

    func open(appState: AppState) {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SettingsWindowView()
            .environmentObject(appState.postureAnalyzer)
            .environmentObject(appState.poseDetector)
            .environmentObject(appState.statsStore)
            .environmentObject(AppSettings.shared)

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "posturapp — Settings"
        win.contentView = NSHostingView(rootView: view)
        win.center()
        win.setFrameAutosaveName("SettingsWindow")
        win.isReleasedWhenClosed = false
        win.delegate = WindowDelegate.shared

        WindowDelegate.shared.onClose = { [weak self] in
            self?.window = nil
            NSApp.setActivationPolicy(.accessory)
        }

        self.window = win

        // Bring app to front so the window is visible
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
        window = nil
        NSApp.setActivationPolicy(.accessory)
    }
}

private final class WindowDelegate: NSObject, NSWindowDelegate {
    static let shared = WindowDelegate()
    var onClose: (() -> Void)?

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}
