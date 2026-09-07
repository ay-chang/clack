import Foundation
import ApplicationServices
import AppKit
import Carbon

enum Permissions {
    /// Whether this process may observe keyboard events.
    ///
    /// Accessibility trust is bound to the app's *code signature*, not its path.
    /// A signature change (a rebuild with an ad-hoc identity, for example) revokes
    /// it silently, which is why release builds must use a stable Developer ID.
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Asks the system to show its one-time Accessibility prompt.
    @discardableResult
    static func requestTrust() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func openAccessibilitySettings() {
        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )!
        NSWorkspace.shared.open(url)
    }

    /// True while a password field (or an app that has left the mode on) has secure
    /// event input enabled. The window server withholds key events from every tap
    /// during this, so the counter legitimately pauses. Surfaced in the UI so a
    /// stalled count doesn't look like a bug.
    static var isSecureInputEnabled: Bool {
        IsSecureEventInputEnabled()
    }
}
