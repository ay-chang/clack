import Foundation
import os

/// A thread-safe tally of keystrokes that have not yet been folded into `Store`.
///
/// The event-tap thread is the only writer; the UI timer on the main thread is the
/// only reader. `increment()` is the hot path — it runs once per physical key press
/// and must stay allocation-free and lock-cheap. An uncontended `os_unfair_lock`
/// costs ~20ns, which is immaterial at human typing rates (~10 events/second), and
/// it keeps the deployment target at macOS 14 (the `Synchronization` module's
/// `Atomic` would require macOS 15).
final class Counter {
    private let pending = OSAllocatedUnfairLock(initialState: 0)

    /// Called from the event-tap thread. Do not add work here.
    func increment() {
        pending.withLock { $0 &+= 1 }
    }

    /// Called from the main thread once per second. Returns and clears the tally.
    func drain() -> Int {
        pending.withLock { value in
            let n = value
            value = 0
            return n
        }
    }
}
