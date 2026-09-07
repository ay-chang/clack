import SwiftUI
import AppKit

@main
struct ClackApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    // Deliberately NOT observing AppModel here: any published change on it would
    // invalidate this body and re-rasterise the status item once a second.
    @ObservedObject private var menuBar = AppModel.shared.menuBar

    var body: some Scene {
        MenuBarExtra {
            PanelView()
                .environmentObject(AppModel.shared)
        } label: {
            MenuBarLabel(text: menuBar.text, warning: menuBar.warning)
        }
        .menuBarExtraStyle(.window)
    }
}

/// The status item's contents. Rendered at most once per second — never per
/// keystroke, which would relayout the whole menu bar at typing speed.
struct MenuBarLabel: View {
    let text: String?
    let warning: Bool

    /// The Clack mark, loaded once and marked as a template so macOS tints it
    /// correctly for light, dark, and inverted menu bars.
    private static let markImage: NSImage? = {
        guard let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.size = NSSize(width: image.size.width / 2, height: image.size.height / 2)
        image.isTemplate = true
        return image
    }()

    var body: some View {
        HStack(spacing: 3) {
            if warning {
                Image(systemName: "exclamationmark.triangle.fill")
            } else if let mark = Self.markImage {
                Image(nsImage: mark)
            } else {
                Image(systemName: "keyboard")
            }
            if let text {
                Text(text).font(.system(size: 12, weight: .medium).monospacedDigit())
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let onboarding = OnboardingController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        AppModel.shared.start()
        if !Permissions.isTrusted {
            onboarding.present()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppModel.shared.terminate()
    }
}
