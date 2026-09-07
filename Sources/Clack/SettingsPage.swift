import SwiftUI
import AppKit

struct SettingsPage: View {
    @EnvironmentObject private var model: AppModel
    @Binding var page: PanelView.Page
    @State private var confirmingReset = false

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                toggle("Launch at login", isOn: $model.launchAtLogin)
                toggle("Show count in menu bar", isOn: $model.showCountInMenuBar)
                toggle(
                    "Count held-key repeats",
                    isOn: $model.countKeyRepeats,
                    help: "Counts every repeat while a key is held down, not just the first press."
                )
            }
            .padding(.horizontal, Theme.padding)
            .padding(.top, 8)

            if let error = model.launchAtLoginError {
                Text(error)
                    .font(Theme.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Theme.padding)
                    .padding(.top, 6)
            }

            Divider()
                .padding(.horizontal, Theme.padding)
                .padding(.vertical, 10)

            SectionLabel(text: "Privacy")
                .padding(.horizontal, Theme.padding)

            Text("Clack records a number, never a keystroke. No key codes are read or stored, and the app makes no network connections.")
                .font(Theme.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.padding)
                .padding(.top, 4)

            Divider()
                .padding(.horizontal, Theme.padding)
                .padding(.vertical, 10)

            VStack(spacing: 0) {
                HoverRow {
                    NSWorkspace.shared.open(
                        URL(string: "https://github.com/ay-chang/clack")!
                    )
                } content: {
                    HStack {
                        Text("View source on GitHub").font(Theme.label)
                        Spacer()
                        Image(systemName: "arrow.up.forward")
                            .font(.system(size: 9, weight: .semibold))
                            .opacity(0.5)
                    }
                }

                HoverRow {
                    if confirmingReset {
                        model.resetAllData()
                        confirmingReset = false
                        page = .stats
                    } else {
                        confirmingReset = true
                    }
                } content: {
                    HStack {
                        Text(confirmingReset ? "Click again to erase all history"
                                             : "Reset all data")
                            .font(Theme.label)
                            .foregroundStyle(confirmingReset ? AnyShapeStyle(.red)
                                                             : AnyShapeStyle(.primary))
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, Theme.padding - 8)

            Text("Version \(version)")
                .font(Theme.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
        }
        .onDisappear { confirmingReset = false }
    }

    private func toggle(_ title: String, isOn: Binding<Bool>, help: String? = nil) -> some View {
        Toggle(isOn: isOn) {
            Text(title).font(Theme.label)
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
        .help(help ?? "")
    }
}
