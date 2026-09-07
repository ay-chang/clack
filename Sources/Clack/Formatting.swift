import Foundation

enum Fmt {
    private static let grouped: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    /// "1,204,553"
    static func full(_ n: Int) -> String {
        grouped.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    /// "847", "1.2k", "12k", "1.2M" — kept narrow so the menu bar item does not
    /// change width (and shove every other item sideways) as the number grows.
    static func compact(_ n: Int) -> String {
        switch n {
        case ..<1_000:
            return "\(n)"
        case ..<10_000:
            return trim(Double(n) / 1_000, "k")
        case ..<1_000_000:
            return "\(n / 1_000)k"
        case ..<10_000_000:
            return trim(Double(n) / 1_000_000, "M")
        default:
            return "\(n / 1_000_000)M"
        }
    }

    private static func trim(_ value: Double, _ suffix: String) -> String {
        let s = String(format: "%.1f", value)
        return (s.hasSuffix(".0") ? String(s.dropLast(2)) : s) + suffix
    }

    static let weekdayInitial: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEEE"
        return f
    }()

    static let mediumDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}
