import SwiftUI
import AppKit

/// First-run window shown when Accessibility access has not been granted.
/// Polls for the grant so the user never has to relaunch the app.
@MainActor
final class OnboardingController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var poller: Timer?

    func present() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(rootView: OnboardingView(controller: self))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Clack"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .windowBackgroundColor
        window.delegate = self
        window.setContentSize(NSSize(width: 420, height: 430))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window

        startPolling()
    }

    private func startPolling() {
        poller?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                guard Permissions.isTrusted else { return }
                AppModel.shared.retryPermission()
                self.dismiss()
            }
        }
        timer.tolerance = 0.25
        RunLoop.main.add(timer, forMode: .common)
        poller = timer
    }

    func dismiss() {
        poller?.invalidate()
        poller = nil
        window?.close()
        window = nil
    }

    func windowWillClose(_ notification: Notification) {
        poller?.invalidate()
        poller = nil
        window = nil
    }
}

struct OnboardingView: View {
    let controller: OnboardingController
    @State private var requested = false

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
                .padding(.top, 26)

            Text("Clack")
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .padding(.top, 12)

            Text("A quiet keystroke counter for your menu bar.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 12) {
                step(1, "Open System Settings › Privacy & Security › Accessibility.")
                step(2, "Turn on the switch next to Clack.")
                step(3, "That's it — this window closes on its own.")
            }
            .padding(.top, 26)
            .padding(.horizontal, 34)

            Text("Clack needs this because macOS treats reading keyboard events as a privileged action. It counts presses and never reads which key you pressed.")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 20)
                .padding(.horizontal, 34)

            Spacer(minLength: 12)

            Button {
                Permissions.requestTrust()
                Permissions.openAccessibilitySettings()
                requested = true
            } label: {
                Text("Open Accessibility Settings")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 34)

            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
                Text(requested ? "Waiting for permission…" : "Not yet granted")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 10)
            .padding(.bottom, 22)
        }
        .frame(width: 420, height: 430)
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 17, height: 17)
                .background(Circle().fill(Theme.accent))
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
