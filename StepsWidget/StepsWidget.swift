import WidgetKit
import SwiftUI
import HealthKit

// MARK: - Colors

private extension Color {
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

private let lightScale: [Color] = [
    Color(hex: "#ebedf0"), Color(hex: "#9be9a8"),
    Color(hex: "#40c463"), Color(hex: "#30a14e"), Color(hex: "#216e39"),
]
private let darkScale: [Color] = [
    Color(hex: "#161b22"), Color(hex: "#0e4429"),
    Color(hex: "#006d32"), Color(hex: "#26a641"), Color(hex: "#39d353"),
]

private func levelFor(_ steps: Int, goal: Int) -> Int {
    guard steps > 0 else { return 0 }
    let r = Double(steps) / Double(goal)
    if r < 0.45 { return 1 }
    if r < 0.80 { return 2 }
    if r < 1.00 { return 3 }
    return 4
}

// MARK: - Number Formatting

private let _wNF: NumberFormatter = {
    let f = NumberFormatter(); f.numberStyle = .decimal; return f
}()
private func wfmt(_ n: Int) -> String { _wNF.string(from: NSNumber(value: n)) ?? "\(n)" }
private func fmtCompact(_ n: Int) -> String { n >= 1000 ? "\(n / 1000)k" : "\(n)" }

private let _standaloneMonthFmt: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "LLL"
    return f
}()
private func standaloneShortMonth(_ date: Date) -> String {
    _standaloneMonthFmt.string(from: date).uppercased()
}

// MARK: - Entry

struct StepsEntry: TimelineEntry {
    let date: Date
    let lastUpdate: Date   // fetch time; render entries share this so elapsed = date - lastUpdate
    let today: Int
    let goal: Int
    let yearDays: [(date: Date, steps: Int, isFuture: Bool)]
    let monthDays: [(date: Date, steps: Int, isFuture: Bool, isToday: Bool)]

    func at(_ d: Date) -> StepsEntry {
        StepsEntry(date: d, lastUpdate: lastUpdate, today: today, goal: goal,
                   yearDays: yearDays, monthDays: monthDays)
    }
}

// localized: "now" / "%d min. ago" / "%d h. ago" — no seconds
private func updatedLabel(elapsed: TimeInterval) -> String {
    let m = Int(elapsed) / 60
    if m < 1 { return Strings.updated_now }
    if m < 60 { return Strings.updated_min_ago(m) }
    return Strings.updated_hours_ago(m / 60)
}

// MARK: - Shared Data Helpers

private let appGroupID = "group.app.steps.Steps"
private let sharedStepsKey = "sharedStepsByDate"
private let sharedGoalKey = "sharedGoal"
private let sharedUpdatedKey = "sharedUpdatedAt"
private let widgetHealthStore = HKHealthStore()

private func savedGoal() -> Int {
    let g = UserDefaults(suiteName: appGroupID)?.integer(forKey: sharedGoalKey) ?? 0
    return g > 0 ? g : 10_000
}

private func cacheToSharedStorage(stepMap: [Date: Int], goal: Int) {
    guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"
    fmt.locale = Locale(identifier: "en_US_POSIX")
    var dict: [String: Int] = [:]
    for (date, steps) in stepMap { dict[fmt.string(from: date)] = steps }
    if let data = try? JSONEncoder().encode(dict) {
        defaults.set(data, forKey: sharedStepsKey)
        defaults.set(goal, forKey: sharedGoalKey)
        defaults.set(Date().timeIntervalSince1970, forKey: sharedUpdatedKey)
    }
}

private func buildStepsEntry(now: Date, lastUpdate: Date, today: Date, todaySteps: Int,
                              stepMap: [Date: Int], goal: Int, cal: Calendar,
                              start: Date, yearEnd: Date) -> StepsEntry {
    var yearDays: [(Date, Int, Bool)] = []
    var cur = start
    while cur <= yearEnd {
        yearDays.append((cur, stepMap[cur] ?? 0, cur > today))
        cur = cal.date(byAdding: .day, value: 1, to: cur)!
    }
    let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: today))!
    var monthDays: [(Date, Int, Bool, Bool)] = []
    cur = monthStart
    let todayMonth = cal.component(.month, from: today)
    while cal.component(.month, from: cur) == todayMonth {
        let steps = stepMap[cur] ?? 0
        monthDays.append((cur, steps, cur > today, cal.isDate(cur, inSameDayAs: today)))
        cur = cal.date(byAdding: .day, value: 1, to: cur)!
    }
    return StepsEntry(date: now, lastUpdate: lastUpdate, today: todaySteps, goal: goal,
                      yearDays: yearDays, monthDays: monthDays)
}

private func fetchStepsAndCache(completion: @escaping (StepsEntry?) -> Void) {
    guard HKHealthStore.isHealthDataAvailable() else { completion(nil); return }
    let type = HKQuantityType(.stepCount)
    let cal = Calendar.current
    let now = Date()
    let today = cal.startOfDay(for: now)
    let year = cal.component(.year, from: today)
    guard let start = cal.date(from: DateComponents(year: year, month: 1, day: 1)),
          let yearEnd = cal.date(from: DateComponents(year: year, month: 12, day: 31))
    else { completion(nil); return }
    var comps = DateComponents(); comps.day = 1
    let pred = HKQuery.predicateForSamples(withStart: start, end: .distantFuture)
    let q = HKStatisticsCollectionQuery(
        quantityType: type,
        quantitySamplePredicate: pred,
        options: .cumulativeSum,
        anchorDate: today,
        intervalComponents: comps
    )
    q.initialResultsHandler = { _, collection, _ in
        guard let collection else { completion(nil); return }
        var stepMap: [Date: Int] = [:]
        collection.enumerateStatistics(from: start, to: yearEnd) { stat, _ in
            stepMap[cal.startOfDay(for: stat.startDate)] =
                Int(stat.sumQuantity()?.doubleValue(for: .count()) ?? 0)
        }
        guard !stepMap.isEmpty else { completion(nil); return }
        let goal = savedGoal()
        let entry = buildStepsEntry(now: now, lastUpdate: now, today: today, todaySteps: stepMap[today] ?? 0,
                                    stepMap: stepMap, goal: goal, cal: cal,
                                    start: start, yearEnd: yearEnd)
        cacheToSharedStorage(stepMap: stepMap, goal: goal)
        completion(entry)
    }
    widgetHealthStore.execute(q)
}

private func readFromSharedStorage() -> StepsEntry? {
    guard let defaults = UserDefaults(suiteName: appGroupID),
          let data = defaults.data(forKey: sharedStepsKey),
          let dict = try? JSONDecoder().decode([String: Int].self, from: data)
    else { return nil }
    let goal = max(1, defaults.integer(forKey: sharedGoalKey))
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"
    fmt.locale = Locale(identifier: "en_US_POSIX")
    var stepMap: [Date: Int] = [:]
    for (key, steps) in dict { if let d = fmt.date(from: key) { stepMap[d] = steps } }
    let cal = Calendar.current
    let now = Date()
    let today = cal.startOfDay(for: now)
    let year = cal.component(.year, from: today)
    guard let start = cal.date(from: DateComponents(year: year, month: 1, day: 1)),
          let yearEnd = cal.date(from: DateComponents(year: year, month: 12, day: 31))
    else { return nil }
    // honest timestamp: when the cache was actually written, not now
    let ts = defaults.double(forKey: sharedUpdatedKey)
    let lastUpdate = ts > 0 ? Date(timeIntervalSince1970: ts) : now
    return buildStepsEntry(now: now, lastUpdate: lastUpdate, today: today, todaySteps: stepMap[today] ?? 0,
                           stepMap: stepMap, goal: goal, cal: cal, start: start, yearEnd: yearEnd)
}

// MARK: - Provider

struct StepsProvider: TimelineProvider {
    typealias Entry = StepsEntry

    func placeholder(in context: Context) -> StepsEntry { makeMockEntry() }

    func getSnapshot(in context: Context, completion: @escaping (StepsEntry) -> Void) {
        completion(readFromSharedStorage() ?? makeMockEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StepsEntry>) -> Void) {
        fetchStepsAndCache { entry in
            let base = entry ?? readFromSharedStorage() ?? makeMockEntry()
            let cal = Calendar.current
            var entries: [StepsEntry] = []
            // 1-min steps for first hour, then 15-min steps up to 4h — lets the
            // "X min/h ago" label tick without extra HealthKit reads
            for m in 0..<60 {
                entries.append(base.at(cal.date(byAdding: .minute, value: m, to: base.lastUpdate)!))
            }
            for m in stride(from: 75, through: 240, by: 15) {
                entries.append(base.at(cal.date(byAdding: .minute, value: m, to: base.lastUpdate)!))
            }
            let next = Date().addingTimeInterval(30 * 60)
            completion(Timeline(entries: entries, policy: .after(next)))
        }
    }

    func makeMockEntry() -> StepsEntry {
        let cal = Calendar.current
        let now = Date()
        let today = cal.startOfDay(for: now)
        let year = cal.component(.year, from: today)
        let start = cal.date(from: DateComponents(year: year, month: 1, day: 1))!
        let yearEnd = cal.date(from: DateComponents(year: year, month: 12, day: 31))!
        var stepMap: [Date: Int] = [:]
        var cur = start
        while cur <= today {
            stepMap[cur] = cal.isDate(cur, inSameDayAs: today) ? 8_432 : mockSteps(for: cur)
            cur = cal.date(byAdding: .day, value: 1, to: cur)!
        }
        return buildStepsEntry(now: now, lastUpdate: now, today: today, todaySteps: 8_432,
                               stepMap: stepMap, goal: 10_000, cal: cal, start: start, yearEnd: yearEnd)
    }

    private func mockSteps(for date: Date) -> Int {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let seed = (c.year ?? 2026) * 10_000 + (c.month ?? 1) * 100 + (c.day ?? 1)
        let r = rng(seed), r2 = rng(seed * 7 + 13), r3 = rng(seed * 31 + 5)
        if r < 0.09 { return Int(r2 * 1_400) }
        let dow = (Calendar.current.dateComponents([.weekday], from: date).weekday ?? 1) - 1
        let weekend = (dow == 0 || dow == 6) ? 2_600 : 0
        let streaky = r3 < 0.18 ? 3_500 : 0
        return Int(2_200 + r2 * 10_600) + weekend + streaky
    }

    private func rng(_ seed: Int) -> Double {
        var a = UInt32(bitPattern: Int32(truncatingIfNeeded: seed))
        a = a &+ 0x6D2B79F5
        var t = (a ^ (a >> 15)) &* (1 | a)
        t = t &+ ((t ^ (t >> 7)) &* (61 | t))
        return Double(t ^ (t >> 14)) / 4_294_967_296.0
    }
}

// MARK: - Theme Helpers

private struct WT {
    let bg: Color
    let text: Color
    let sub: Color
    let gray: Color
    let border: Color
    let scale: [Color]
    var accent: Color { scale[isDark ? 4 : 3] }
    let isDark: Bool

    init(_ dark: Bool) {
        isDark = dark
        scale  = dark ? darkScale : lightScale
        bg     = dark ? Color(hex: "#0d1117") : .white
        text   = dark ? Color(hex: "#e6edf3") : Color(hex: "#1f2328")
        sub    = dark ? Color(hex: "#7d8590") : Color(hex: "#59636e")
        gray   = dark ? Color(hex: "#21262d") : Color(hex: "#dfe3e8")
        border = dark ? Color.white.opacity(0.06) : Color.black.opacity(0.05)
    }
}

// MARK: - Three Month Heatmap (current + 2 previous, each as separate panel)

private struct ThreeMonthsHeatmap: View {
    let allYearDays: [(date: Date, steps: Int, isFuture: Bool)]
    let goal: Int
    let scale: [Color]
    let grayColor: Color
    let subColor: Color
    let todayBorderColor: Color

    private let gap: CGFloat = 2
    private let panelGap: CGFloat = 8
    private let radius: CGFloat = 2.5
    private let labelHeight: CGFloat = 18 // label font + spacing

    private typealias HDay = (date: Date, steps: Int, isFuture: Bool)

    private func daysFor(monthOffset: Int, cal: Calendar, today: Date) -> [HDay] {
        let anchor = cal.date(byAdding: .month, value: monthOffset, to: today)!
        let start = cal.date(from: cal.dateComponents([.year, .month], from: anchor))!
        var endComps = cal.dateComponents([.year, .month], from: anchor)
        endComps.month = (endComps.month ?? 1) + 1
        let end = cal.date(byAdding: .day, value: -1, to: cal.date(from: endComps)!)!
        let byDate = Dictionary(allYearDays.map { (cal.startOfDay(for: $0.date), $0.steps) },
                                uniquingKeysWith: { f, _ in f })
        var days: [HDay] = []
        var cur = start
        while cur <= end {
            days.append((cur, byDate[cur] ?? 0, cur > today))
            cur = cal.date(byAdding: .day, value: 1, to: cur)!
        }
        return days
    }

    private func labelFor(monthOffset: Int, cal: Calendar, today: Date) -> String {
        let d = cal.date(byAdding: .month, value: monthOffset, to: today)!
        return standaloneShortMonth(d)
    }

    var body: some View {
        GeometryReader { geo in
            let cal = Calendar.current
            let today = cal.startOfDay(for: Date())
            let panelW = (geo.size.width - panelGap * 2) / 3
            let canvasH = max(1, geo.size.height - labelHeight)
            // cellH fills full canvas height; cellW fills panel width — cells are rectangular
            let cellH = max(1, (canvasH - gap * 7) / 8)

            HStack(alignment: .top, spacing: panelGap) {
                ForEach([-2, -1, 0], id: \.self) { offset in
                    let days = daysFor(monthOffset: offset, cal: cal, today: today)
                    let label = labelFor(monthOffset: offset, cal: cal, today: today)
                    let numCols = max(1, (days.count + 7) / 8)
                    let cellW = max(1, (panelW + gap) / CGFloat(numCols) - gap)
                    let cell = min(cellH, cellW)

                    VStack(alignment: .leading, spacing: 7) {
                        Text(label)
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.2)
                            .foregroundColor(subColor)
                        Canvas { ctx, _ in
                            for (i, d) in days.enumerated() {
                                let col = i / 8
                                let row = i % 8
                                let rect = CGRect(
                                    x: CGFloat(col) * (cell + gap),
                                    y: CGFloat(row) * (cell + gap),
                                    width: cell, height: cell
                                )
                                ctx.fill(
                                    Path(roundedRect: rect, cornerRadius: radius),
                                    with: .color(d.isFuture || d.steps == 0
                                                 ? grayColor
                                                 : scale[levelFor(d.steps, goal: goal)])
                                )
                                if cal.isDate(d.date, inSameDayAs: today) {
                                    let borderRect = rect.insetBy(dx: -0.75, dy: -0.75)
                                    ctx.stroke(
                                        Path(roundedRect: borderRect, cornerRadius: radius + 0.75),
                                        with: .color(todayBorderColor.opacity(0.7)),
                                        lineWidth: 1.0
                                    )
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(width: panelW, alignment: .topLeading)
                    .frame(maxHeight: .infinity)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

// MARK: - Month Grid (no leading offset, today has accent ring)

private struct MonthGrid: View {
    let days: [(date: Date, steps: Int, isFuture: Bool, isToday: Bool)]
    let goal: Int
    let scale: [Color]
    let grayColor: Color
    let todayBorderColor: Color
    private static let cols = 7
    private static let gap: CGFloat = 3.5

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: Self.gap), count: Self.cols),
            spacing: Self.gap
        ) {
            ForEach(0..<days.count, id: \.self) { i in
                let d = days[i]
                ZStack {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(d.isFuture || d.steps == 0
                              ? grayColor
                              : scale[levelFor(d.steps, goal: goal)])
                    if d.isToday {
                        RoundedRectangle(cornerRadius: 3.25)
                            .stroke(todayBorderColor.opacity(0.7), lineWidth: 1.0)
                            .padding(-0.75)
                    }
                }
                .aspectRatio(1, contentMode: .fit)
            }
        }
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let entry: StepsEntry
    @Environment(\.colorScheme) private var cs
    private var t: WT { WT(cs == .dark) }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Left: today stats
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(Strings.today_label)
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(t.sub)
                        .padding(.bottom, 5)
                    Text(wfmt(entry.today))
                        .font(.system(size: 27, weight: .heavy))
                        .monospacedDigit()
                        .foregroundColor(t.text)
                        .padding(.bottom, 3)
                    Text(Strings.of_goal(goal: fmtCompact(entry.goal)))
                        .font(.system(size: 10.5))
                        .foregroundColor(t.sub)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text(Strings.last_update_label)
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(t.sub)
                    Text(updatedLabel(elapsed: entry.date.timeIntervalSince(entry.lastUpdate)))
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.2)
                        .monospacedDigit()
                        .foregroundColor(t.sub)
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .frame(width: 104)

            // Right: 3-month heatmap panels
            ThreeMonthsHeatmap(
                allYearDays: entry.yearDays,
                goal: entry.goal,
                scale: t.scale,
                grayColor: t.gray,
                subColor: t.sub,
                todayBorderColor: t.text
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.leading, 10)
        .padding(.trailing, 14)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(t.bg, for: .widget)
    }
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let entry: StepsEntry
    @Environment(\.colorScheme) private var cs
    private var t: WT { WT(cs == .dark) }

    private var currentMonthName: String {
        guard let date = entry.monthDays.first?.date else { return Strings.month_label }
        return standaloneShortMonth(date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                Text(Strings.today_label)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(t.sub)
                HStack(alignment: .lastTextBaseline, spacing: 5) {
                    Text(wfmt(entry.today))
                        .font(.system(size: 20, weight: .heavy))
                        .monospacedDigit()
                        .foregroundColor(t.text)
                        .layoutPriority(1)
                    Text(updatedLabel(elapsed: entry.date.timeIntervalSince(entry.lastUpdate)))
                        .font(.system(size: 9, weight: .semibold))
                        .monospacedDigit()
                        .foregroundColor(t.sub)
                }
            }
            .padding(.bottom, 6)
            Text(currentMonthName)
                .font(.system(size: 9, weight: .bold))
                .tracking(0.8)
                .foregroundColor(t.sub)
                .padding(.bottom, 4)
            MonthGrid(days: entry.monthDays, goal: entry.goal,
                      scale: t.scale, grayColor: t.gray, todayBorderColor: t.text)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(t.bg, for: .widget)
    }
}

// MARK: - Widget Configurations

struct StepsMediumWidget: Widget {
    let kind = "StepsMediumWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StepsProvider()) { entry in
            MediumWidgetView(entry: entry)
        }
        .configurationDisplayName(Strings.widget_medium_name)
        .description(Strings.widget_medium_description)
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

struct StepsSmallWidget: Widget {
    let kind = "StepsSmallWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StepsProvider()) { entry in
            SmallWidgetView(entry: entry)
        }
        .configurationDisplayName(Strings.widget_small_name)
        .description(Strings.widget_small_description)
        .supportedFamilies([.systemSmall])
    }
}
