import Foundation
import CoreGraphics
import os

// MARK: - The C callback (hot path)
//
// This runs synchronously inside the system's event-delivery path, once per key
// press, on the dedicated tap thread. It does exactly two things: bump an integer,
// or re-arm the tap. No allocation, no logging, no disk I/O, no UI work — anything
// slow here costs the user keyboard latency and eventually gets the tap disabled
// by the window server for exceeding its timeout.
//
// The tap is created with `.listenOnly`, so the return value is ignored and this
// code is structurally incapable of modifying or swallowing a key event.
//
// NOTE: key *codes* are never read, stored, or transmitted. The event is used only
// to ask whether it was an auto-repeat. See PRIVACY.md.
private func keyCountEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return nil }
    let tap = Unmanaged<KeyEventTap>.fromOpaque(refcon).takeUnretainedValue()

    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        // Expected, not exceptional: the system disables taps that run long or
        // when the user forces input. Re-arm rather than dying silently.
        tap.reenable()

    case .keyDown:
        if !tap.countsRepeats.withLock({ $0 }),
           event.getIntegerValueField(.keyboardEventAutorepeat) != 0 {
            break
        }
        tap.counter.increment()

    default:
        break
    }

    return nil
}

// MARK: - Tap lifecycle

/// Owns a listen-only `CGEventTap` running on its own thread.
final class KeyEventTap {
    enum StartError: Error, LocalizedError {
        case notTrusted
        case tapCreationFailed

        var errorDescription: String? {
            switch self {
            case .notTrusted:
                return "Clack has not been granted Accessibility permission."
            case .tapCreationFailed:
                return "The system refused to create the keyboard event tap."
            }
        }
    }

    let counter: Counter
    /// Whether keys held down should count once per repeat. Read from the tap thread.
    let countsRepeats = OSAllocatedUnfairLock(initialState: false)

    private var machPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tapRunLoop: CFRunLoop?
    private var thread: Thread?
    private(set) var isRunning = false

    init(counter: Counter) {
        self.counter = counter
    }

    /// Starts the tap on a dedicated thread. Blocks briefly until the tap is armed
    /// (or has failed) so the caller gets a truthful result.
    @discardableResult
    func start() throws -> Bool {
        guard !isRunning else { return true }
        guard Permissions.isTrusted else { throw StartError.notTrusted }

        let ready = DispatchSemaphore(value: 0)
        var created = false

        let thread = Thread { [weak self] in
            guard let self else { ready.signal(); return }

            let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            let refcon = Unmanaged.passUnretained(self).toOpaque()

            guard let port = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .listenOnly,
                eventsOfInterest: mask,
                callback: keyCountEventTapCallback,
                userInfo: refcon
            ) else {
                ready.signal()
                return
            }

            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
            self.machPort = port
            self.runLoopSource = source
            self.tapRunLoop = CFRunLoopGetCurrent()

            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: port, enable: true)

            created = true
            ready.signal()

            // Parks this thread on its run loop. It wakes only to service key events.
            CFRunLoopRun()
        }
        thread.name = "com.clack.eventtap"
        thread.qualityOfService = .userInteractive
        thread.stackSize = 128 * 1024
        self.thread = thread
        thread.start()

        // The tap is created synchronously on the new thread; this wait is bounded
        // and only happens at launch or after a permission change.
        _ = ready.wait(timeout: .now() + 3)

        guard created else {
            self.thread = nil
            throw StartError.tapCreationFailed
        }

        isRunning = true
        return true
    }

    func stop() {
        guard isRunning else { return }
        if let port = machPort {
            CGEvent.tapEnable(tap: port, enable: false)
            CFMachPortInvalidate(port)
        }
        if let loop = tapRunLoop {
            if let source = runLoopSource {
                CFRunLoopRemoveSource(loop, source, .commonModes)
            }
            CFRunLoopStop(loop)
        }
        machPort = nil
        runLoopSource = nil
        tapRunLoop = nil
        thread = nil
        isRunning = false
    }

    /// Called from the tap thread when the system disables the tap.
    fileprivate func reenable() {
        guard let port = machPort else { return }
        CGEvent.tapEnable(tap: port, enable: true)
    }

    /// True when the tap exists but the system has stopped delivering events to it.
    var isTapEnabled: Bool {
        guard let port = machPort else { return false }
        return CGEvent.tapIsEnabled(tap: port)
    }
}
