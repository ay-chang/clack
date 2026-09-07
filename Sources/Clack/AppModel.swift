import Foundation
import SwiftUI
import ServiceManagement
import AppKit

/// Drives the status item alone.
///
/// The menu bar label must not re-render at typing speed: every re-render makes
/// AppKit rasterise the view and relayout the whole menu bar. Observing the full
/// `AppModel` would do exactly that, because *any* `@Published` change on it
/// invalidates the `App` body. So the label observes only this, and these values
/// are reassigned only when they actually differ — which for a compact count
/// like "1.2k" is a few times an hour, not once a second.
@MainActor
final class MenuBarState: ObservableObject {
    @Published private(set) var text: String?
    @Published private(set) var warning = false

    func update(text newText: String?, warning newWarning: Bool) {
        if newText != text { text = newText }
        if newWarning != warning { warning = newWarning }
    }
}

@MainActor
final class AppModel: ObservableObject {
    let menuBar = MenuBarState()

    static let shared = AppModel()

    // MARK: Stats
    @Published private(set) var today = 0
    @Published private(set) var week = 0
    @Published private(set) var allTime = 0
    @Published private(set) var streak = 0
    @Published private(set) var bestDay: DayCount?
    @Published private(set) var lastSeven: [DayCount] = []
    @Published private(set) var firstDay: Date?

    // MARK: Status
    @Published private(set) var isTrusted = false
    @Published private(set) var isSecureInputActive = false

    // MARK: Preferences
    @Published var showCountInMenuBar: Bool {
        didSet {
            defaults.set(showCountInMenuBar, forKey: Keys.showCount)
            syncMenuBar()
        }
    }
    @Published var countKeyRepeats: Bool {
        didSet {
            defaults.set(countKeyRepeats, forKey: Keys.countRepeats)
            let value = countKeyRepeats
            tap.countsRepeats.withLock { $0 = value }
        }
    }
    @Published var launchAtLogin: Bool {
        didSet { applyLaunchAtLogin() }
    }
    @Published var launchAtLoginError: String?

    private enum Keys {
        static let showCount = "showCountInMenuBar"
        static let countRepeats = "countKeyRepeats"
    }

    private let defaults = UserDefaults.standard
    private let counter = Counter()
    private let store = Store()
    private lazy var tap = KeyEventTap(counter: counter)

    private var ticker: Timer?
    private var ticks = 0
    private var currentDayKey = ""

    // `Calendar.current` re-resolves and copies a Calendar on every access, and
    // date-component math is not cheap. Both are fixed for a whole day, so
    // resolve them once at rollover instead of twice per tick while typing.
    private var calendar = Calendar.current
    private var todayStart = Calendar.current.startOfDay(for: Date())

    private init() {
        defaults.register(defaults: [Keys.showCount: false, Keys.countRepeats: false])
        showCountInMenuBar = defaults.bool(forKey: Keys.showCount)
        countKeyRepeats = defaults.bool(forKey: Keys.countRepeats)
        launchAtLogin = SMAppService.mainApp.status == .enabled

        currentDayKey = Store.dayFormatter.string(from: Date())
        let repeats = countKeyRepeats
        tap.countsRepeats.withLock { $0 = repeats }
        refreshStats()
    }

    // MARK: - Lifecycle

    func start() {
        isTrusted = Permissions.isTrusted
        if isTrusted { startTap() }
        startTicker()
        observeSystemEvents()
    }

    private func startTap() {
        do {
            try tap.start()
        } catch {
            NSLog("Clack: could not start event tap — \(error.localizedDescription)")
        }
    }

    /// Called by the onboarding window's poller once the user grants permission.
    func retryPermission() {
        let trusted = Permissions.isTrusted
        isTrusted = trusted
        if trusted && !tap.isRunning { startTap() }
    }

    private func startTicker() {
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        // The dominant battery cost of an app like this is not CPU time, it is
        // *waking the CPU out of idle*. A tolerance lets macOS coalesce our
        // wakeup with ones it was going to perform anyway, instead of forcing a
        // dedicated wake every second. A quarter-second of jitter on a
        // once-a-second counter is invisible.
        timer.tolerance = 0.25
        // .common so the counter keeps updating while the menu bar panel is open.
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func observeSystemEvents() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.store.flushSynchronously() }
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.terminate() }
        }
    }

    func terminate() {
        _ = drain()
        store.flushSynchronously()
        tap.stop()
    }

    // MARK: - Tick

    @discardableResult
    private func drain() -> Int {
        let n = counter.drain()
        if n > 0 { store.add(n) }
        return n
    }

    private func tick() {
        ticks += 1
        let n = drain()
        let dayKey = Store.dayFormatter.string(from: Date())
        let rolledOver = dayKey != currentDayKey
        if rolledOver {
            currentDayKey = dayKey
            // Picks up a timezone change too, not just midnight.
            calendar = Calendar.current
            todayStart = calendar.startOfDay(for: Date())
        }

        // Recomputing every statistic each second is wasteful: `allTime`,
        // `bestDay` and `firstDay` are O(days recorded), and `streak` and
        // `lastSevenDays` do Calendar arithmetic. Only today's bucket changes
        // between ticks, so fold the delta in and leave the rest alone. A full
        // recompute runs on day rollover and once a minute as a safety net.
        if rolledOver || ticks % 60 == 0 {
            refreshStats()
        } else if n > 0 {
            applyIncrement(n)
        }

        syncMenuBar()

        // Trust can change at any time — granted after the onboarding window was
        // dismissed, or revoked from System Settings while running. While
        // untrusted, check every tick so the app starts counting the moment the
        // user flips the switch; once trusted, once a minute is plenty.
        if !isTrusted || ticks % 60 == 0 {
            let trusted = Permissions.isTrusted
            if trusted != isTrusted { isTrusted = trusted; syncMenuBar() }
            if trusted && !tap.isRunning {
                startTap()
            } else if !trusted && tap.isRunning {
                tap.stop()
            }
        }

        if ticks % 60 == 0 {
            store.flush()
            isSecureInputActive = Permissions.isSecureInputEnabled
        }
    }

    /// Folds `n` new keystrokes into the published stats without rescanning history.
    private func applyIncrement(_ n: Int) {
        let wasIdleToday = today == 0
        today += n
        week += n
        allTime += n

        if let last = lastSeven.last, last.date == todayStart {
            lastSeven[lastSeven.count - 1] = DayCount(date: todayStart, count: today)
        }

        if today > (bestDay?.count ?? 0) {
            bestDay = DayCount(date: todayStart, count: today)
        }

        // The only cheap-to-miss case: today just became a counting day.
        if wasIdleToday { streak = store.streak }
    }

    private func syncMenuBar() {
        menuBar.update(
            text: showCountInMenuBar ? Fmt.compact(today) : nil,
            warning: !isTrusted
        )
    }

    private func refreshStats() {
        today = store.today
        week = store.weekTotal()
        allTime = store.allTime
        streak = store.streak
        bestDay = store.bestDay
        lastSeven = store.lastSevenDays()
        firstDay = store.firstDay
        syncMenuBar()
    }

    // MARK: - Actions

    func resetAllData() {
        _ = counter.drain()
        store.reset()
        refreshStats()
    }

    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    // MARK: - Presentation helpers

    /// Height fractions for the seven-day chart, normalised to the busiest day.
    var chartScale: Int {
        max(lastSeven.map(\.count).max() ?? 0, 1)
    }
}
