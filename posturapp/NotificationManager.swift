import Combine
import UserNotifications

final class NotificationManager: ObservableObject {

    @Published var authorizationGranted = false

    private let center = UNUserNotificationCenter.current()
    private let alertIdentifier = "posture.bad.alert"
    private var lastMemeIndex = -1

    // MARK: - Funny content pools

    private let titles = [
        "🍌 Banana Mode Activated",
        "🐢 Turtle Mode Detected",
        "🗼 Leaning Tower of You",
        "💀 Your Spine Called",
        "🦒 Be a Giraffe, Not a Shrimp",
        "🤕 Your Chiropractor is Thrilled",
        "🧘 Namaste... but sit up first",
        "📐 You're at a 45° angle bro",
        "🪑 A chair, not a hammock",
        "🎪 The circus called",
    ]

    private let bodies = [
        "You've been bent like a banana for 30 seconds. SIT. UP.",
        "Turtle mode is not a lifestyle. Uncurl. Now.",
        "Leaning Tower of You — at least Pisa gets tourists.",
        "Your spine wants a lawyer. Straighten up before it files.",
        "Giraffes have long necks for a reason. Emulate them.",
        "Your chiropractor loves this. You won't love the bill.",
        "Inner peace requires a straight back. Get to work.",
        "You're doing geometry with your spine. Stop it.",
        "You're melting into your chair like butter. Resist.",
        "The circus called — they need their contortionist back.",
    ]

    private let memeFiles = ["meme1.png","meme2.png","meme3.png","meme4.png","meme5.png","meme6.png"]

    // MARK: - Public API

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async { self.authorizationGranted = granted }
        }
    }

    func scheduleAlert(reason: String) {
        let idx = randomIndex(avoiding: lastMemeIndex, count: titles.count)
        lastMemeIndex = idx

        // Full-screen overlay — the main "boom" effect
        DispatchQueue.main.async {
            AlertOverlayManager.shared.show(
                title: self.titles[idx],
                message: self.bodies[idx],
                memeIndex: idx
            )
        }

        // Also send a notification for when the app is in background / popover closed
        let content = UNMutableNotificationContent()
        content.title = titles[idx]
        content.body = bodies[idx]
        content.sound = .default

        let memeFile = memeFiles[idx % memeFiles.count]
        if let memeURL = memeURL(for: memeFile),
           let tempURL = copyToTemp(url: memeURL, name: memeFile),
           let attachment = try? UNNotificationAttachment(
               identifier: "meme",
               url: tempURL,
               options: [UNNotificationAttachmentOptionsTypeHintKey: "public.png"]
           ) {
            content.attachments = [attachment]
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: alertIdentifier, content: content, trigger: trigger)
        center.add(request)
    }

    func cancelAlert() {
        center.removePendingNotificationRequests(withIdentifiers: [alertIdentifier])
    }

    // MARK: - Helpers

    private func randomIndex(avoiding last: Int, count: Int) -> Int {
        guard count > 1 else { return 0 }
        var idx = Int.random(in: 0..<count)
        if idx == last { idx = (idx + 1) % count }
        return idx
    }

    private func memeURL(for filename: String) -> URL? {
        // Memes are bundled in the app under Resources/Memes/
        Bundle.main.url(forResource: filename.components(separatedBy: ".").first,
                        withExtension: "png",
                        subdirectory: "Memes")
        ?? Bundle.main.url(forResource: filename.components(separatedBy: ".").first,
                           withExtension: "png")
    }

    // UNNotificationAttachment requires a file URL it can read — copy to temp dir
    private func copyToTemp(url: URL, name: String) -> URL? {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: tmp)
        do {
            try FileManager.default.copyItem(at: url, to: tmp)
            return tmp
        } catch {
            return nil
        }
    }
}
