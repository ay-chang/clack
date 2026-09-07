import SwiftUI

enum Theme {
    static let panelWidth: CGFloat = 296
    static let padding: CGFloat = 16
    static let corner: CGFloat = 7

    /// Follows the user's system accent so the app feels native rather than branded.
    static var accent: Color { Color(nsColor: .controlAccentColor) }

    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded).monospacedDigit()
    }

    static var label: Font { .system(size: 12, weight: .regular) }
    static var value: Font { .system(size: 12, weight: .medium).monospacedDigit() }
    static var caption: Font { .system(size: 10.5, weight: .regular) }
    static var sectionTitle: Font { .system(size: 10, weight: .semibold) }
}

/// A row that highlights on hover, the way a real menu item does.
struct HoverRow<Content: View>: View {
    var action: () -> Void
    @ViewBuilder var content: Content

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(hovering ? Theme.accent : .clear)
                )
                .foregroundStyle(hovering ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(Theme.sectionTitle)
            .kerning(0.6)
            .foregroundStyle(.tertiary)
    }
}

struct StatRow: View {
    let label: String
    let value: String
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(Theme.label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            if let detail {
                Text(detail)
                    .font(Theme.caption)
                    .foregroundStyle(.tertiary)
            }
            Text(value)
                .font(Theme.value)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
    }
}
