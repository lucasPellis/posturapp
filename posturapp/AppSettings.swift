import Foundation
import Combine

final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    // MARK: - Detection

    @Published var alertThreshold: Double {
        didSet { UserDefaults.standard.set(alertThreshold, forKey: "alertThreshold") }
    }
    @Published var alertCooldown: Double {
        didSet { UserDefaults.standard.set(alertCooldown, forKey: "alertCooldown") }
    }
    @Published var leanForwardTolerance: Double {
        didSet { UserDefaults.standard.set(leanForwardTolerance, forKey: "leanForwardTolerance") }
    }
    @Published var slouchTolerance: Double {
        didSet { UserDefaults.standard.set(slouchTolerance, forKey: "slouchTolerance") }
    }

    // MARK: - UI

    @Published var showSkeleton: Bool {
        didSet { UserDefaults.standard.set(showSkeleton, forKey: "showSkeleton") }
    }
    @Published var enableFullScreenOverlay: Bool {
        didSet { UserDefaults.standard.set(enableFullScreenOverlay, forKey: "enableFullScreenOverlay") }
    }
    @Published var enableNotifications: Bool {
        didSet { UserDefaults.standard.set(enableNotifications, forKey: "enableNotifications") }
    }

    private init() {
        let d = UserDefaults.standard
        alertThreshold        = d.object(forKey: "alertThreshold")        as? Double ?? 30
        alertCooldown         = d.object(forKey: "alertCooldown")         as? Double ?? 30
        leanForwardTolerance  = d.object(forKey: "leanForwardTolerance")  as? Double ?? 0.20
        slouchTolerance       = d.object(forKey: "slouchTolerance")       as? Double ?? 0.25
        showSkeleton          = d.object(forKey: "showSkeleton")          as? Bool   ?? true
        enableFullScreenOverlay = d.object(forKey: "enableFullScreenOverlay") as? Bool ?? true
        enableNotifications   = d.object(forKey: "enableNotifications")   as? Bool   ?? true
    }
}
