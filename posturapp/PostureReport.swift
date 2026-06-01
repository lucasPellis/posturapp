import Foundation

struct PostureReport {
    let period: Period
    let score: Double
    let goodMinutes: Double
    let badMinutes: Double
    let topIssue: String?
    let longestStreak: TimeInterval
    let totalAlerts: Int
    let generatedAt: Date

    enum Period { case daily, weekly }

    // MARK: - Funny copy tiers

    var emoji: String {
        switch score {
        case 85...: return "🏆"
        case 70..<85: return "📊"
        case 50..<70: return "📞"
        case 30..<50: return "🍌"
        default:      return "🚨"
        }
    }

    var headline: String {
        switch score {
        case 85...: return "Certified Spine Champion"
        case 70..<85: return "Not Bad, Not Great"
        case 50..<70: return "Your Spine Called"
        case 30..<50: return "Banana Mode: Activated"
        default:      return "Emergency Posture Report"
        }
    }

    var roast: String {
        let periodStr = period == .daily ? "today" : "this week"
        switch score {
        case 85...:
            return "You sat like an actual human being \(periodStr). We're genuinely proud. Tell your mom."
        case 70..<85:
            return "You tried \(periodStr). Sometimes. The data shows... inconsistency. Like your life choices."
        case 50..<70:
            return "Your spine said it's not angry, just disappointed. \(periodStr.capitalized). That's worse."
        case 30..<50:
            return "You bent like a banana for most of \(periodStr). At least bananas are healthy."
        default:
            return "Your chiropractor has sent flowers. To your spine. As condolences. For \(periodStr)."
        }
    }

    var issueRoast: String? {
        guard let issue = topIssue else { return nil }
        switch issue {
        case let s where s.contains("slouch"):
            return "Main villain: Slouching 🐢 — You were basically a shrimp."
        case let s where s.contains("leaning"):
            return "Main villain: Screen Leaning 🖥️ — The screen didn't move. You did."
        case let s where s.contains("uneven"):
            return "Main villain: Uneven Shoulders 📐 — Gravity had favorites today."
        default:
            return "Main villain: \(issue)"
        }
    }

    var streakComment: String {
        let mins = Int(longestStreak / 60)
        switch mins {
        case 60...: return "Best streak: \(mins) min 🔥 — Impressive. Suspicious, even."
        case 20..<60: return "Best streak: \(mins) min — Not bad. Not great. Not nothing."
        case 5..<20: return "Best streak: \(mins) min — Your spine had a short moment of hope."
        default:     return "Best streak: \(Int(longestStreak))s — The spine never stood a chance."
        }
    }

    var alertsComment: String {
        switch totalAlerts {
        case 0: return "Alerts fired: 0 — Either perfect or we couldn't find you. 👀"
        case 1: return "Alerts fired: 1 — One warning. One ignored."
        case 2...4: return "Alerts fired: \(totalAlerts) — We tried. You didn't."
        default: return "Alerts fired: \(totalAlerts) — At this point we're basically roommates."
        }
    }

    var periodLabel: String {
        let df = DateFormatter()
        if period == .daily {
            df.dateFormat = "EEEE, MMM d"
            return df.string(from: generatedAt)
        } else {
            df.dateFormat = "MMM d"
            let weekAgo = Calendar.current.date(byAdding: .day, value: -6, to: generatedAt)!
            return "\(df.string(from: weekAgo)) – \(df.string(from: generatedAt))"
        }
    }

    // MARK: - Factory

    static func daily(from store: PostureStatsStore) -> PostureReport {
        let stats = store.dailyStats(forLast: 1).first ?? DailyStats(date: Date(), goodSeconds: 0, badSeconds: 0)
        let topIssue = topIssue(from: store, days: 1)
        let alerts = store.events.filter {
            $0.type == .bad &&
            Calendar.current.isDateInToday($0.startedAt)
        }.count

        return PostureReport(
            period: .daily,
            score: stats.score,
            goodMinutes: stats.goodSeconds / 60,
            badMinutes: stats.badSeconds / 60,
            topIssue: topIssue,
            longestStreak: store.longestGoodStreak(),
            totalAlerts: alerts,
            generatedAt: Date()
        )
    }

    static func weekly(from store: PostureStatsStore) -> PostureReport {
        let days = store.dailyStats(forLast: 7)
        let avgScore = days.isEmpty ? 0 : days.map(\.score).reduce(0, +) / Double(days.count)
        let good = days.map(\.goodSeconds).reduce(0, +)
        let bad  = days.map(\.badSeconds).reduce(0, +)
        let topIssue = topIssue(from: store, days: 7)
        let alerts = store.events.filter {
            $0.type == .bad &&
            $0.startedAt > Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        }.count

        return PostureReport(
            period: .weekly,
            score: avgScore,
            goodMinutes: good / 60,
            badMinutes: bad / 60,
            topIssue: topIssue,
            longestStreak: store.longestGoodStreak(),
            totalAlerts: alerts,
            generatedAt: Date()
        )
    }

    private static func topIssue(from store: PostureStatsStore, days: Int) -> String? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        var totals: [String: Double] = [:]
        for event in store.events where event.type == .bad && event.startedAt > cutoff {
            if let r = event.reason { totals[r, default: 0] += event.duration }
        }
        return totals.max(by: { $0.value < $1.value })?.key
    }
}
