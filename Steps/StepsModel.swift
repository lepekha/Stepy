import SwiftUI

// MARK: - Color Utilities

extension Color {
    init(hex: String) {
        var h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        self.init(
            red:   Double((v >> 16) & 0xFF) / 255,
            green: Double((v >>  8) & 0xFF) / 255,
            blue:  Double( v        & 0xFF) / 255
        )
    }
}

// MARK: - GitHub Theme

struct GHTheme {
    let bg, text, sub, faint, tile, border, track: Color

    static let light = GHTheme(
        bg:     Color(hex: "#ffffff"),
        text:   Color(hex: "#1f2328"),
        sub:    Color(hex: "#59636e"),
        faint:  Color(hex: "#818b98"),
        tile:   Color(hex: "#f6f8fa"),
        border: Color(hex: "#d0d7de"),
        track:  Color(hex: "#eaeef2")
    )

    static let dark = GHTheme(
        bg:     Color(hex: "#0d1117"),
        text:   Color(hex: "#e6edf3"),
        sub:    Color(hex: "#7d8590"),
        faint:  Color(hex: "#484f58"),
        tile:   Color(hex: "#161b22"),
        border: Color(hex: "#21262d"),
        track:  Color(hex: "#21262d")
    )
}

// MARK: - Heat Palette (green, 5 levels 0=empty)

struct HeatPalette {
    let colors: [Color]

    func accent(dark: Bool) -> Color { dark ? colors[4] : colors[3] }

    static let light = HeatPalette(colors: [
        Color(hex: "#ebedf0"), Color(hex: "#9be9a8"),
        Color(hex: "#40c463"), Color(hex: "#30a14e"), Color(hex: "#216e39")
    ])

    static let dark = HeatPalette(colors: [
        Color(hex: "#161b22"), Color(hex: "#0e4429"),
        Color(hex: "#006d32"), Color(hex: "#26a641"), Color(hex: "#39d353")
    ])
}

// MARK: - Step Day

struct StepDay: Identifiable {
    let id: Int
    let date: Date
    let steps: Int
}

// MARK: - Stats

struct StepStats {
    let today: Int
    let average: Int
    let total: Int
    let record: Int
    let recordDate: Date?
    let streak: Int
    let dayCount: Int
}

// MARK: - Model

struct StepsModel {
    let days: [StepDay]
    let stats: StepStats
    let goal: Int

    static func build(goal: Int = 10_000, todaySteps: Int = 8_432) -> StepsModel {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let year = cal.component(.year, from: today)
        let start   = cal.date(from: DateComponents(year: year, month: 1,  day: 1))!
        let yearEnd = cal.date(from: DateComponents(year: year, month: 12, day: 31))!

        var days: [StepDay] = []
        var cur = start
        while cur <= yearEnd {
            let steps = cur <= today ? makeSteps(date: cur) : 0
            days.append(StepDay(id: days.count, date: cur, steps: steps))
            cur = cal.date(byAdding: .day, value: 1, to: cur)!
        }

        // Recent past days get realistic boosts so streak reads naturally
        let boosts = [12_480, 10_960, 13_210, 11_540, 10_720, 12_030]
        let todayIdx = days.firstIndex { cal.isDate($0.date, inSameDayAs: today) } ?? (days.count - 1)
        days[todayIdx] = StepDay(id: todayIdx, date: days[todayIdx].date, steps: todaySteps)
        for i in 1...min(boosts.count, todayIdx) {
            let j = todayIdx - i
            days[j] = StepDay(id: j, date: days[j].date, steps: boosts[i - 1])
        }

        let pastDays = days.filter { $0.date <= today }
        var total = 0, record = 0
        var recordDate: Date?
        for d in pastDays {
            total += d.steps
            if d.steps > record { record = d.steps; recordDate = d.date }
        }

        var streak = 0
        for d in pastDays.dropLast().reversed() {
            if d.steps >= goal { streak += 1 } else { break }
        }

        let stats = StepStats(
            today: todaySteps,
            average: total / max(1, pastDays.count),
            total: total,
            record: record,
            recordDate: recordDate,
            streak: streak,
            dayCount: pastDays.count
        )
        return StepsModel(days: days, stats: stats, goal: goal)
    }

    static func level(_ steps: Int, goal: Int) -> Int {
        guard steps > 0 else { return 0 }
        let r = Double(steps) / Double(goal)
        if r < 0.45 { return 1 }
        if r < 0.80 { return 2 }
        if r < 1.00 { return 3 }
        return 4
    }

    private static func makeSteps(date: Date) -> Int {
        let c = Calendar.current.dateComponents([.year, .month, .day, .weekday], from: date)
        let seed = (c.year ?? 2026) * 10_000 + (c.month ?? 1) * 100 + (c.day ?? 1)
        let r  = rng(seed)
        let r2 = rng(seed * 7 + 13)
        let r3 = rng(seed * 31 + 5)
        let dow = (c.weekday ?? 1) - 1
        if r < 0.09 { return Int(r2 * 1_400) }
        let weekend = (dow == 0 || dow == 6) ? 2_600 : 0
        let streaky = r3 < 0.18 ? 3_500 : 0
        return Int(2_200 + r2 * 10_600) + weekend + streaky
    }

    // Mulberry32 — matches the JS prototype's deterministic RNG
    private static func rng(_ seed: Int) -> Double {
        var a = UInt32(bitPattern: Int32(truncatingIfNeeded: seed))
        a = a &+ 0x6D2B79F5
        var t = (a ^ (a >> 15)) &* (1 | a)
        t = t &+ ((t ^ (t >> 7)) &* (61 | t))
        t = t ^ (t >> 14)
        return Double(t) / 4_294_967_296.0
    }
}

// MARK: - Number Formatting

private let _nf: NumberFormatter = {
    let f = NumberFormatter(); f.numberStyle = .decimal; return f
}()

func fmt(_ n: Int) -> String {
    _nf.string(from: NSNumber(value: n)) ?? "\(n)"
}

func fmtCompact(_ n: Int) -> String {
    switch n {
    case 1_000_000...:
        let v = Double(n) / 1_000_000
        let s = String(format: v >= 10 ? "%.0fM" : "%.2fM", v)
        return s.hasSuffix(".00M") ? "\(Int(v))M" : s
    case 10_000...: return "\(n / 1_000)K"
    case 1_000...:  return n % 1_000 == 0 ? "\(n / 1_000)K" : String(format: "%.1fK", Double(n) / 1_000)
    default:        return "\(n)"
    }
}

private let fmtDayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.setLocalizedDateFormatFromTemplate("LLLd")
    return f
}()

private let fmtDayFullFormatter: DateFormatter = {
    let f = DateFormatter()
    f.setLocalizedDateFormatFromTemplate("MMMdyyyy")
    return f
}()

private let fmtMonthYearFormatter: DateFormatter = {
    let f = DateFormatter()
    f.setLocalizedDateFormatFromTemplate("LLLy")
    return f
}()

func fmtDay(_ date: Date?) -> String {
    guard let d = date else { return "" }
    return fmtDayFormatter.string(from: d)
}

func fmtDayFull(_ date: Date?) -> String {
    guard let d = date else { return "" }
    return fmtDayFullFormatter.string(from: d)
}

func fmtMonthYear(_ date: Date) -> String {
    fmtMonthYearFormatter.string(from: date)
}
