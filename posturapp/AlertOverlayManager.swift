import AppKit
import SwiftUI

final class AlertOverlayManager {

    static let shared = AlertOverlayManager()
    private var overlayWindow: NSWindow?
    private var dismissTimer: Timer?

    private init() {}

    func show(title: String, message: String, memeIndex: Int) {
        guard overlayWindow == nil else { return }

        guard let screen = NSScreen.main else { return }

        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        window.backgroundColor = .clear
        window.isOpaque = false
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = AlertOverlayView(title: title, message: message, memeIndex: memeIndex) {
            self.dismiss()
        }
        window.contentView = NSHostingView(rootView: view)
        window.makeKeyAndOrderFront(nil)
        self.overlayWindow = window

        playAlertSound()

        dismissTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { _ in
            self.dismiss()
        }
    }

    func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
    }

    private func playAlertSound() {
        // Cycle through dramatic system sounds
        let sounds = ["Funk", "Basso", "Sosumi", "Glass"]
        let name = sounds[Int.random(in: 0..<sounds.count)]
        NSSound(named: NSSound.Name(name))?.play()
    }
}
