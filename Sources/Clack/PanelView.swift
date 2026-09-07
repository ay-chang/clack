import SwiftUI
import AppKit

struct PanelView: View {
    @EnvironmentObject private var model: AppModel
    @State private var page: Page = .stats

    enum Page { case stats, settings }

    var body: some View {
        VStack(spacing: 0) {
            header
            Group {
                switch page {
                case .stats:    statsPage
                case .settings: SettingsPage(page: $page)
                }
            }
            .transition(.opacity)
        }
        .padding(.vertical, 10)
        .frame(width: Theme.panelWidth)
        .animation(.easeInOut(duration: 0.15), value: page)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 6) {
            if page == .settings {
                Button {
                    page = .stats
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text(page == .settings ? "Settings" : "Clack")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            if page == .stats {
                Button {
                    page = .settings
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
        }
        .padding(.horizontal, Theme.padding)
        .padding(.bottom, 4)
    }

    // MARK: Stats

    private var statsPage: some View {
        VStack(spacing: 0) {
            if !model.isTrusted {
                PermissionBanner()
                    .padding(.horizontal, Theme.padding)
                    .padding(.top, 6)
            }

            headline
                .padding(.top, model.isTrusted ? 10 : 14)

            WeekChart(days: model.lastSeven, scale: model.chartScale)
                .padding(.horizontal, Theme.padding)
                .padding(.top, 16)

            Divider()
                .padding(.horizontal, Theme.padding)
                .padding(.top, 14)
                .padding(.bottom, 6)

            VStack(spacing: 0) {
                StatRow(label: "This week", value: Fmt.full(model.week))
                StatRow(
                    label: "Best day",
                    value: Fmt.full(model.bestDay?.count ?? 0),
                    detail: model.bestDay.map { Fmt.mediumDate.string(from: $0.date) }
                )
                StatRow(label: "All time", value: Fmt.full(model.allTime))
                if model.streak > 1 {
                    StatRow(
                        label: "Streak",
                        value: "\(model.streak) days"
                    )
                }
            }
            .padding(.horizontal, Theme.padding - 8)

            Divider()
                .padding(.horizontal, Theme.padding)
                .padding(.vertical, 6)

            VStack(spacing: 0) {
                HoverRow {
                    NSApplication.shared.terminate(nil)
                } content: {
                    HStack {
                        Text("Quit Clack").font(Theme.label)
                        Spacer()
                        Text("⌘Q").font(Theme.caption).opacity(0.6)
                    }
                }
                .keyboardShortcut("q", modifiers: .command)
            }
            .padding(.horizontal, Theme.padding - 8)
        }
    }

    private var headline: some View {
        VStack(spacing: 1) {
            Text(Fmt.full(model.today))
                .font(Theme.display(38))
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.25), value: model.today)
                .foregroundStyle(.primary)

            if model.isSecureInputActive {
                Label("Paused — secure input active", systemImage: "lock.fill")
                    .font(Theme.caption)
                    .foregroundStyle(.orange)
            } else {
                Text("keys today")
                    .font(Theme.label)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Permission banner

struct PermissionBanner: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Accessibility access needed", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.orange)

            Text("Clack can't count keystrokes until macOS grants it Accessibility access.")
                .font(Theme.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Permissions.openAccessibilitySettings()
            } label: {
                Text("Open System Settings")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .fill(Color.orange.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.25), lineWidth: 0.5)
        )
    }
}
