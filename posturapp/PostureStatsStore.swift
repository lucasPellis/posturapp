import Foundation
import Combine

struct PostureEvent: Codable, Identifiable {
    let id: UUID
    let startedAt: Date
    var endedAt: Date?
    let type: EventType
    let reason: String?

    enum EventType: String, Codable { case good, bad, unknown }

    var duration: TimeInterval {
        (endedAt ?? Date()).timeIntervalSince(startedAt)
    }
}

struct DailyStats {
    let date: Date
    let goodSeconds: Double
    let badSeconds: Double
    var score: Double {
        let total = goodSeconds + badSeconds
        guard total > 0 else { return 0 }
        return goodSeconds / total * 100
    }
}

struct HourlyBucket {
    let hour: Int
    let goodSeconds: Double
    let badSeconds: Double
}

final class PostureStatsStore: ObservableObject {

    @Published var events: [PostureEvent] = []

    private let key = "posture.events"
    private var currentEventId: UUID?

    init() { load() }

    // MARK: - Recording

    func record(state: PostureState) {
        let type: PostureEvent.EventType
        let reason: String?

        switch state {
        case .good:    type = .good;    reason = nil
        case .bad(let r): type = .bad; reason = r
        default:       type = .unknown; reason = nil
        }

        // Close current event
        if let id = currentEventId, let idx = events.firstIndex(where: { $0.id == id }) {
            events[idx].endedAt = Date()
        }

        // Start new event
        let event = PostureEvent(id: UUID(), startedAt: Date(), endedAt: nil, type: type, reason: reason)
        events.append(event)
        currentEventId = event.id

        pruneOldEvents()
        save()
    }

    // MARK: - Queries

    func dailyStats(forLast days: Int) -> [DailyStats] {
        let calendar = Calendar.current
        let now = Date()

        return (0..<days).reversed().map { offset -> DailyStats in
            let date = calendar.date(byAdding: .day, value: -offset, to: now)!
            let start = calendar.startOfDay(for: date)
            let end   = calendar.date(byAdding: .day, value: 1, to: start)!

            let dayEvents = events.filter { e in
                let s = e.startedAt
                return s >= start && s < end
            }

            let good = dayEvents.filter { $0.type == .good }.reduce(0) { $0 + $1.duration }
            let bad  = dayEvents.filter { $0.type == .bad  }.reduce(0) { $0 + $1.duration }

            return DailyStats(date: date, goodSeconds: good, badSeconds: bad)
        }
    }

    func todayHourlyBuckets() -> [HourlyBucket] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())

        return (0..<24).map { hour -> HourlyBucket in
            let hStart = calendar.date(byAdding: .hour, value: hour, to: start)!
            let hEnd   = calendar.date(byAdding: .hour, value: 1, to: hStart)!

            let hourEvents = events.filter { e in
                let s = e.startedAt
                return s >= hStart && s < hEnd
            }

            let good = hourEvents.filter { $0.type == .good }.reduce(0) { $0 + $1.duration }
            let bad  = hourEvents.filter { $0.type == .bad  }.reduce(0) { $0 + $1.duration }
            return HourlyBucket(hour: hour, goodSeconds: good, badSeconds: bad)
        }
    }

    func todayScore() -> Double {
        dailyStats(forLast: 1).first?.score ?? 0
    }

    func longestGoodStreak() -> TimeInterval {
        events
            .filter { $0.type == .good }
            .map { $0.duration }
            .max() ?? 0
    }

    func totalBadToday() -> TimeInterval {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        return events
            .filter { $0.type == .bad && $0.startedAt >= start }
            .reduce(0) { $0 + $1.duration }
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([PostureEvent].self, from: data)
        else { return }
        events = decoded
    }

    private func pruneOldEvents() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        events = events.filter { $0.startedAt > cutoff }
    }
}
