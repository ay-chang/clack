import SwiftUI

/// Seven bars, one per day, normalised to the busiest day in the window.
/// Monochrome except today, which takes the system accent.
struct WeekChart: View {
    let days: [DayCount]
    let scale: Int

    private let barHeight: CGFloat = 46
    private let minBar: CGFloat = 3

    @State private var hovered: Date?

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(days) { day in
                    bar(for: day)
                }
            }
            .frame(height: barHeight)

            HStack(spacing: 6) {
                ForEach(days) { day in
                    Text(Fmt.weekdayInitial.string(from: day.date))
                        .font(Theme.caption)
                        .foregroundStyle(isToday(day) ? AnyShapeStyle(Theme.accent)
                                                      : AnyShapeStyle(.tertiary))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .overlay(alignment: .top) {
            if let hovered, let day = days.first(where: { $0.date == hovered }) {
                Text("\(Fmt.full(day.count)) on \(Fmt.mediumDate.string(from: day.date))")
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(.thickMaterial)
                    )
                    .offset(y: -18)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.12), value: hovered)
    }

    private func bar(for day: DayCount) -> some View {
        let fraction = min(CGFloat(day.count) / CGFloat(max(scale, 1)), 1)
        let height = max(minBar, fraction * barHeight)

        return VStack {
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(fill(for: day))
                .frame(height: height)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onHover { inside in
            hovered = inside ? day.date : (hovered == day.date ? nil : hovered)
        }
    }

    private func fill(for day: DayCount) -> AnyShapeStyle {
        if isToday(day) {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Theme.accent, Theme.accent.opacity(0.65)],
                    startPoint: .top, endPoint: .bottom
                )
            )
        }
        let emphasised = hovered == day.date
        return AnyShapeStyle(Color.primary.opacity(emphasised ? 0.35 : 0.18))
    }

    private func isToday(_ day: DayCount) -> Bool {
        Calendar.current.isDateInToday(day.date)
    }
}
