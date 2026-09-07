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
    /// Point height of the mark in the menu bar.
    ///
    /// Not the ~16pt a tall SF Symbol occupies: this mark is wide (5:3) and
    /// solid black, so matching that height makes it noticeably bulkier than the
    /// system icons beside it. 11pt puts its *width* in line with neighbours.
    private static let markHeight: CGFloat = 11

    private static let markImage: NSImage? = {
        guard let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return nil }
        let aspect = image.size.width / max(image.size.height, 1)
        image.size = NSSize(width: markHeight * aspect, height: markHeight)
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
