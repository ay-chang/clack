import Foundation

/// On-disk shape. One integer per calendar day — nothing about *which* keys.
struct History: Codable {
    var version: Int = 1
    var days: [String: Int] = [:]
}

struct DayCount: Identifiable, Hashable {
    let date: Date
    let count: Int
    var id: Date { date }
}

/// Owns the keystroke history and its persistence.
///
/// Mutated only from the main thread. Writes are batched (every 60s, plus on
/// terminate and on sleep) and performed off-thread — writing once per keystroke
/// would put a filesystem round-trip in the typing path.
final class Store {
    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private let fileURL: URL
    private let ioQueue = DispatchQueue(label: "com.clack.store", qos: .utility)
    private(set) var history = History()
    private var isDirty = false

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Clack", isDirectory: true)
            try? FileManager.default.createDirectory(
                at: base, withIntermediateDirectories: true
            )
            self.fileURL = base.appendingPathComponent("history.json")
        }
        load()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode(History.self, from: data) {
            history = decoded
        }
    }

    /// Writes if anything changed. Safe to call often.
    func flush() {
        guard isDirty else { return }
        isDirty = false
        let snapshot = history
        let url = fileURL
        ioQueue.async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Blocking write, for app termination where the async queue may not drain.
    func flushSynchronously() {
        guard isDirty else { return }
        isDirty = false
        guard let data = try? JSONEncoder().encode(history) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Mutation

    func add(_ n: Int, on date: Date = Date()) {
        guard n > 0 else { return }
        let key = Self.dayFormatter.string(from: date)
        history.days[key, default: 0] += n
        isDirty = true
    }

    func reset() {
        history = History()
        isDirty = true
        flushSynchronously()
    }

    // MARK: - Derived stats

    func count(on date: Date) -> Int {
        history.days[Self.dayFormatter.string(from: date)] ?? 0
    }

    var today: Int { count(on: Date()) }

    var allTime: Int { history.days.values.reduce(0, +) }

    /// Last seven days, oldest first, including today (zero-filled).
    func lastSevenDays(now: Date = Date()) -> [DayCount] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        return (0..<7).reversed().compactMap { offset in
            guard let date = cal.date(byAdding: .day, value: -offset, to: start) else {
                return nil
            }
            return DayCount(date: date, count: count(on: date))
        }
    }

    func weekTotal(now: Date = Date()) -> Int {
        lastSevenDays(now: now).reduce(0) { $0 + $1.count }
    }

    var bestDay: DayCount? {
        guard let best = history.days.max(by: { $0.value < $1.value }),
              let date = Self.dayFormatter.date(from: best.key)
        else { return nil }
        return DayCount(date: date, count: best.value)
    }

    /// Consecutive days ending today (or yesterday) with at least one keystroke.
    var streak: Int {
        let cal = Calendar.current
        var day = cal.startOfDay(for: Date())
        if count(on: day) == 0 {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: day),
                  count(on: yesterday) > 0 else { return 0 }
            day = yesterday
        }
        var n = 0
        while count(on: day) > 0 {
            n += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return n
    }

    var firstDay: Date? {
        history.days.keys.min().flatMap { Self.dayFormatter.date(from: $0) }
    }
}
