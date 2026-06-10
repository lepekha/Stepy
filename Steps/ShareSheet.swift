import SwiftUI
import UIKit

// MARK: - Static Heat Grid
// Uses eager VStack/HStack (not LazyVGrid) so ImageRenderer captures all cells.

private struct StaticHeatGrid: View {
    let days: [StepDay]
    let goal: Int
    let palette: HeatPalette
    let today: Date
    var cols: Int = 28
    var cellSize: CGFloat = 10.5
    var gap: CGFloat = 1.5

    private var rows: [[StepDay]] {
        stride(from: 0, to: days.count, by: cols).map {
            Array(days[$0..<min($0 + cols, days.count)])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: gap) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: gap) {
                    ForEach(row) { day in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(cellColor(day))
                            .frame(width: cellSize, height: cellSize)
                    }
                    if row.count < cols {
                        ForEach(0..<(cols - row.count), id: \.self) { _ in
                            Color.clear.frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
        }
    }

    private func cellColor(_ day: StepDay) -> Color {
        day.date > today
            ? palette.colors[0]
            : palette.colors[StepsModel.level(day.steps, goal: goal)]
    }
}

// MARK: - Steps Badge

private struct StepsBadge: View {
    let accentColor: Color
    let subColor: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(accentColor).frame(width: 7, height: 7)
            Text("STEPS")
                .font(.system(size: 11, weight: .black))
                .kerning(1.8)
                .foregroundColor(subColor)
        }
    }
}

// MARK: - Shared footer stats row

private struct StatsFooter: View {
    let items: [(String, String)]
    let theme: GHTheme
    let sub: Color

    var body: some View {
        HStack(alignment: .top) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, s in
                if i > 0 { Spacer() }
                let align: HorizontalAlignment = i == 0 ? .leading : (i == 1 ? .center : .trailing)
                VStack(alignment: align, spacing: 2) {
                    Text(s.0)
                        .font(.system(size: 18, weight: .black))
                        .kerning(-0.3).monospacedDigit()
                        .foregroundColor(theme.text)
                    Text(s.1)
                        .font(.system(size: 9.5, weight: .semibold))
                        .kerning(0.8).textCase(.uppercase)
                        .foregroundColor(sub)
                }
                .frame(maxWidth: .infinity, alignment: Alignment(horizontal: align, vertical: .top))
            }
        }
    }
}

// MARK: - Share Card: Today (390×390)

struct ShareCardToday: View {
    let stats: StepStats
    let goal: Int
    let palette: HeatPalette
    let isDark: Bool
    let date: Date

    private var theme: GHTheme { isDark ? .dark : .light }
    private var accent: Color { palette.accent(dark: isDark) }
    private var sub: Color { isDark ? .white.opacity(0.42) : .black.opacity(0.42) }
    private var pct: Int { min(100, Int((Double(stats.today) / Double(goal) * 100).rounded())) }

    private static let months = ["Jan","Feb","Mar","Apr","May","Jun",
                                  "Jul","Aug","Sep","Oct","Nov","Dec"]
    private var dateStr: String {
        let c = Calendar.current.dateComponents([.month, .day, .year], from: date)
        return "\(Self.months[(c.month ?? 1) - 1]) \(c.day ?? 1), \(c.year ?? 2026)"
    }

    var body: some View {
        ZStack {
            theme.bg
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    StepsBadge(accentColor: accent, subColor: sub)
                    Spacer()
                    Text(dateStr).font(.system(size: 11)).foregroundColor(sub)
                }
                .padding(.bottom, 24)

                Spacer()
                VStack(alignment: .leading, spacing: 9) {
                    Text(fmt(stats.today))
                        .font(.system(size: 82, weight: .black))
                        .kerning(-3.5).monospacedDigit()
                        .foregroundColor(theme.text)
                    Text(Strings.share_steps_today)
                        .font(.system(size: 13, weight: .semibold))
                        .kerning(1.2).textCase(.uppercase)
                        .foregroundColor(sub)
                }
                Spacer()

                progressBar(pct: pct)
                    .padding(.bottom, 22)

                Rectangle().fill(theme.border).frame(height: 1).padding(.bottom, 16)

                StatsFooter(items: [
                    (fmtCompact(stats.average), Strings.share_avg_per_day),
                    (fmtCompact(stats.total),   Strings.share_total),
                    (fmtCompact(stats.record),  Strings.share_record),
                ], theme: theme, sub: sub)
            }
            .padding(28)
        }
        .frame(width: 390, height: 390)
    }

    @ViewBuilder
    private func progressBar(pct: Int) -> some View {
        VStack(spacing: 0) {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.track)
                    Capsule()
                        .fill(accent)
                        .frame(width: g.size.width * CGFloat(pct) / 100)
                }
                .frame(height: 7)
            }
            .frame(height: 7).padding(.bottom, 8)
            HStack {
                Text(Strings.percent_of_goal(percent: pct))
                    .font(.system(size: 12, weight: .bold)).foregroundColor(accent)
                Spacer()
                Text("\(Strings.share_goal_label) \(fmt(goal))")
                    .font(.system(size: 12)).foregroundColor(sub)
            }
        }
    }
}

// MARK: - Share Card: Day (390×390)

struct ShareCardDay: View {
    let day: StepDay
    let stats: StepStats
    let goal: Int
    let palette: HeatPalette
    let isDark: Bool

    private var theme: GHTheme { isDark ? .dark : .light }
    private var accent: Color { palette.accent(dark: isDark) }
    private var sub: Color { isDark ? .white.opacity(0.42) : .black.opacity(0.42) }
    private var pct: Int { min(100, Int((Double(day.steps) / Double(goal) * 100).rounded())) }

    var body: some View {
        ZStack {
            theme.bg
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    StepsBadge(accentColor: accent, subColor: sub)
                    Spacer()
                    Text(fmtDayFull(day.date)).font(.system(size: 11)).foregroundColor(sub)
                }
                .padding(.bottom, 24)

                Spacer()
                VStack(alignment: .leading, spacing: 9) {
                    Text(fmt(day.steps))
                        .font(.system(size: 82, weight: .black))
                        .kerning(-3.5).monospacedDigit()
                        .foregroundColor(theme.text)
                    Text(Strings.steps_unit.uppercased())
                        .font(.system(size: 13, weight: .semibold))
                        .kerning(1.2)
                        .foregroundColor(sub)
                }
                Spacer()

                VStack(spacing: 0) {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(theme.track)
                            Capsule()
                                .fill(accent)
                                .frame(width: g.size.width * CGFloat(pct) / 100)
                        }
                        .frame(height: 7)
                    }
                    .frame(height: 7).padding(.bottom, 8)
                    HStack {
                        Text(Strings.percent_of_goal(percent: pct))
                            .font(.system(size: 12, weight: .bold)).foregroundColor(accent)
                        Spacer()
                        Text("\(Strings.share_goal_label) \(fmt(goal))")
                            .font(.system(size: 12)).foregroundColor(sub)
                    }
                }
                .padding(.bottom, 22)

                Rectangle().fill(theme.border).frame(height: 1).padding(.bottom, 16)

                StatsFooter(items: [
                    (fmtCompact(stats.average), Strings.share_avg_per_day),
                    (fmtCompact(stats.total),   Strings.share_total),
                    (fmtCompact(stats.record),  Strings.share_record),
                ], theme: theme, sub: sub)
            }
            .padding(28)
        }
        .frame(width: 390, height: 390)
    }
}

// MARK: - Share Card: Weekly (390×390)

struct ShareCardWeekly: View {
    let stats: StepStats
    let goal: Int
    let palette: HeatPalette
    let isDark: Bool
    let days: [StepDay]

    private var theme: GHTheme { isDark ? .dark : .light }
    private var accent: Color { palette.accent(dark: isDark) }
    private var sub: Color { isDark ? .white.opacity(0.42) : .black.opacity(0.42) }
    private var emptyBar: Color { isDark ? Color(hex: "#161b22") : Color(hex: "#f0f2f4") }

    private static let dow    = ["Su","Mo","Tu","We","Th","Fr","Sa"]
    private static let months = ["Jan","Feb","Mar","Apr","May","Jun",
                                  "Jul","Aug","Sep","Oct","Nov","Dec"]

    private var last7: [StepDay] {
        let today = Calendar.current.startOfDay(for: Date())
        return Array(days.filter { $0.date <= today }.suffix(7))
    }
    private var wGoal: Int { last7.filter { $0.steps >= goal }.count }
    private var wAvg:  Int { last7.isEmpty ? 0 : last7.reduce(0) { $0 + $1.steps } / max(1, last7.count) }
    private var wBest: Int { last7.map(\.steps).max() ?? 0 }
    private var maxSteps: Int { max(last7.map(\.steps).max() ?? 1, Int(Double(goal) * 1.05)) }

    private var rangeText: String {
        guard let f = last7.first, let l = last7.last else { return "" }
        let fc = Calendar.current.dateComponents([.month, .day], from: f.date)
        let lc = Calendar.current.dateComponents([.month, .day, .year], from: l.date)
        let fm = Self.months[(fc.month ?? 1) - 1], lm = Self.months[(lc.month ?? 1) - 1]
        return "\(fm) \(fc.day ?? 1) – \(lm) \(lc.day ?? 1), \(lc.year ?? 2026)"
    }

    private let chartH: CGFloat = 148
    private let labelH: CGFloat = 22

    var body: some View {
        ZStack {
            theme.bg
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    StepsBadge(accentColor: accent, subColor: sub)
                    Spacer()
                    Text(rangeText).font(.system(size: 10.5)).foregroundColor(sub)
                }
                .padding(.bottom, 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(Strings.share_this_week)
                        .font(.system(size: 20, weight: .black)).kerning(-0.3)
                        .foregroundColor(theme.text)
                    Text(Strings.share_days_goal_reached(wGoal, last7.count))
                        .font(.system(size: 11.5)).foregroundColor(sub)
                }
                .padding(.bottom, 14)

                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(last7.enumerated()), id: \.offset) { _, day in
                        let h = max(CGFloat(day.steps) / CGFloat(maxSteps) * chartH, 2)
                        let met = day.steps >= goal
                        let d = Self.dow[Calendar.current.component(.weekday, from: day.date) - 1]
                        VStack(spacing: 4) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(met ? AnyShapeStyle(accent) : AnyShapeStyle(emptyBar))
                                .frame(height: h)
                            Text(d)
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(met ? accent : sub)
                        }
                    }
                }
                .frame(height: chartH + labelH)
                .padding(.bottom, 14)

                Rectangle().fill(theme.border).frame(height: 1).padding(.bottom, 14)

                StatsFooter(items: [
                    (fmtCompact(wAvg),  Strings.share_avg_per_day),
                    (fmtCompact(wBest), Strings.share_best_day),
                    ("\(wGoal)/7",      Strings.share_goal_days),
                ], theme: theme, sub: sub)
            }
            .padding(28)
        }
        .frame(width: 390, height: 390)
    }
}

// MARK: - Share Card: Year (390×693)

struct ShareCardYear: View {
    let stats: StepStats
    let goal: Int
    let palette: HeatPalette
    let isDark: Bool
    let days: [StepDay]

    private var theme: GHTheme { isDark ? .dark : .light }
    private var accent: Color { palette.accent(dark: isDark) }
    private var sub: Color { isDark ? .white.opacity(0.42) : .black.opacity(0.42) }
    private var tile: Color { isDark ? Color(hex: "#161b22") : Color(hex: "#f6f8fa") }

    private var today: Date { Calendar.current.startOfDay(for: Date()) }
    private var realDays: [StepDay] { days.filter { $0.date <= today } }
    private var goalDays: Int { realDays.filter { $0.steps >= goal }.count }
    private var successRate: Int {
        realDays.isEmpty ? 0 : Int((Double(goalDays) / Double(realDays.count) * 100).rounded())
    }

    private static let months = ["Jan","Feb","Mar","Apr","May","Jun",
                                  "Jul","Aug","Sep","Oct","Nov","Dec"]
    private var rangeText: String {
        guard let f = days.first, let l = days.last else { return "" }
        let fc = Calendar.current.dateComponents([.month, .year], from: f.date)
        let lc = Calendar.current.dateComponents([.month, .year], from: l.date)
        let fm = Self.months[(fc.month ?? 1) - 1], lm = Self.months[(lc.month ?? 1) - 1]
        return "\(fm) \(fc.year ?? 2026) – \(lm) \(lc.year ?? 2026)"
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            theme.bg

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    StepsBadge(accentColor: accent, subColor: sub)
                    Spacer()
                    Text(rangeText).font(.system(size: 10.5)).foregroundColor(sub)
                }
                .padding(.bottom, 22)

                Text(fmtCompact(stats.total))
                    .font(.system(size: 62, weight: .black))
                    .kerning(-2.5).monospacedDigit()
                    .foregroundColor(theme.text)
                Text(Strings.share_total_steps_year)
                    .font(.system(size: 14)).foregroundColor(sub)
                    .padding(.top, 8).padding(.bottom, 20)

                // heatmap: 28 cols × 10.5pt + gap 1.5 ≈ 335×167
                StaticHeatGrid(
                    days: days, goal: goal, palette: palette, today: today,
                    cols: 28, cellSize: 10.5, gap: 1.5
                )
                .padding(.bottom, 12)

                HStack(spacing: 4) {
                    Text(Strings.legend_less).font(.system(size: 9)).foregroundColor(sub)
                    ForEach(0..<5, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(palette.colors[i])
                            .frame(width: 10, height: 10)
                    }
                    Text(Strings.legend_more).font(.system(size: 9)).foregroundColor(sub)
                }
                .padding(.bottom, 22)

                // stats: manual 2-col grid (no LazyVGrid for ImageRenderer compat)
                let items: [(String, String)] = [
                    (fmtCompact(stats.total),   Strings.share_total_steps),
                    (fmtCompact(stats.record),  Strings.share_record_day),
                    ("\(goalDays)",              Strings.share_days_at_goal),
                    (fmtCompact(stats.average), Strings.share_daily_avg),
                    ("\(successRate)%",         Strings.share_success_rate),
                ]
                VStack(spacing: 10) {
                    ForEach(Array(stride(from: 0, to: items.count, by: 2).map { i -> (Int, [(String,String)]) in
                        (i, Array(items[i..<min(i+2, items.count)]))
                    }), id: \.0) { _, row in
                        HStack(spacing: 10) {
                            ForEach(Array(row.enumerated()), id: \.offset) { _, item in
                                statTile(item.0, item.1)
                            }
                            if row.count < 2 { Color.clear.frame(maxWidth: .infinity) }
                        }
                    }
                }

                Spacer()

                Rectangle().fill(theme.border).frame(height: 1).padding(.vertical, 16)
                HStack {
                    Spacer()
                    StepsBadge(accentColor: accent, subColor: sub)
                    Spacer()
                }
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 28)
        }
        .frame(width: 390, height: 693)
    }

    @ViewBuilder
    private func statTile(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .black)).kerning(-0.2).monospacedDigit()
                .foregroundColor(theme.text)
            Text(label)
                .font(.system(size: 9, weight: .semibold)).kerning(0.7).textCase(.uppercase)
                .foregroundColor(sub)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(tile)
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }
}

// MARK: - Share Progress Sheet

struct ShareProgressSheet: View {
    let days: [StepDay]
    let stats: StepStats
    let goal: Int
    let selectedDay: StepDay?
    let palette: HeatPalette
    let isDark: Bool

    @State private var selectedCard = 0
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

    private var theme: GHTheme { isDark ? .dark : .light }
    private var accent: Color { palette.accent(dark: isDark) }

    private struct CardInfo { let id: Int; let label: String; let w: CGFloat; let h: CGFloat }

    private var cards: [CardInfo] {
        if selectedDay != nil {
            return [
                CardInfo(id: 0, label: Strings.share_day,    w: 390, h: 390),
                CardInfo(id: 1, label: Strings.share_today,  w: 390, h: 390),
                CardInfo(id: 2, label: Strings.share_weekly, w: 390, h: 390),
                CardInfo(id: 3, label: Strings.share_year,   w: 390, h: 693),
            ]
        } else {
            return [
                CardInfo(id: 0, label: Strings.share_today,  w: 390, h: 390),
                CardInfo(id: 1, label: Strings.share_weekly, w: 390, h: 390),
                CardInfo(id: 2, label: Strings.share_year,   w: 390, h: 693),
            ]
        }
    }

    private let thumbW: CGFloat = 84
    private let thumbScale: CGFloat = 84.0 / 390.0

    @ViewBuilder
    private func cardView(_ id: Int) -> some View {
        let today = Calendar.current.startOfDay(for: Date())
        if let day = selectedDay {
            switch id {
            case 0: ShareCardDay(day: day, stats: stats, goal: goal, palette: palette, isDark: isDark)
            case 1: ShareCardToday(stats: stats, goal: goal, palette: palette, isDark: isDark, date: today)
            case 2: ShareCardWeekly(stats: stats, goal: goal, palette: palette, isDark: isDark, days: days)
            default: ShareCardYear(stats: stats, goal: goal, palette: palette, isDark: isDark, days: days)
            }
        } else {
            switch id {
            case 0: ShareCardToday(stats: stats, goal: goal, palette: palette, isDark: isDark, date: today)
            case 1: ShareCardWeekly(stats: stats, goal: goal, palette: palette, isDark: isDark, days: days)
            default: ShareCardYear(stats: stats, goal: goal, palette: palette, isDark: isDark, days: days)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(isDark ? Color.white.opacity(0.18) : Color.black.opacity(0.14))
                .frame(width: 34, height: 4)
                .padding(.top, 10).padding(.bottom, 4)

            HStack {
                Text(Strings.share_your_progress)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(theme.text)
                Spacer()
                Button { dismiss() } label: {
                    ZStack {
                        Circle()
                            .fill(isDark ? Color.white.opacity(0.09) : Color.black.opacity(0.06))
                            .frame(width: 27, height: 27)
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(theme.sub)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(cards, id: \.id) { card in
                        let thumbH = card.h * thumbScale
                        VStack(spacing: 7) {
                            cardView(card.id)
                                .frame(width: card.w, height: card.h)
                                .scaleEffect(thumbScale, anchor: .topLeading)
                                .frame(width: thumbW, height: thumbH, alignment: .topLeading)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                                .opacity(selectedCard == card.id ? 1.0 : 0.45)
                                .animation(.easeInOut(duration: 0.15), value: selectedCard)
                                .onTapGesture { selectedCard = card.id }

                            Text(card.label)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(selectedCard == card.id ? theme.text : theme.sub)
                        }
                    }
                }
                .padding(.horizontal, 18).padding(.bottom, 16)
            }

            VStack(spacing: 9) {
                Button {
                    Task { await shareImage() }
                } label: {
                    HStack(spacing: 8) {
                        if isSaving {
                            Text(Strings.share_preparing)
                        } else {
                            Image(systemName: "square.and.arrow.up").font(.system(size: 14, weight: .semibold))
                            Text(Strings.share_button)
                        }
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
                .opacity(isSaving ? 0.72 : 1)

                Button { dismiss() } label: {
                    Text(Strings.share_cancel)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(theme.sub)
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(isDark ? Color.white.opacity(0.07) : Color.black.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18).padding(.bottom, 36)
        }
        .background(theme.bg.ignoresSafeArea())
    }

    @MainActor
    private func shareImage() async {
        isSaving = true
        let today = Calendar.current.startOfDay(for: Date())
        let card = cards[selectedCard]

        let uiImage: UIImage?
        if let day = selectedDay {
            switch selectedCard {
            case 0:
                let r = ImageRenderer(content:
                    ShareCardDay(day: day, stats: stats, goal: goal, palette: palette, isDark: isDark)
                        .frame(width: card.w, height: card.h))
                r.scale = 2.77; uiImage = r.uiImage
            case 1:
                let r = ImageRenderer(content:
                    ShareCardToday(stats: stats, goal: goal, palette: palette, isDark: isDark, date: today)
                        .frame(width: card.w, height: card.h))
                r.scale = 2.77; uiImage = r.uiImage
            case 2:
                let r = ImageRenderer(content:
                    ShareCardWeekly(stats: stats, goal: goal, palette: palette, isDark: isDark, days: days)
                        .frame(width: card.w, height: card.h))
                r.scale = 2.77; uiImage = r.uiImage
            default:
                let r = ImageRenderer(content:
                    ShareCardYear(stats: stats, goal: goal, palette: palette, isDark: isDark, days: days)
                        .frame(width: card.w, height: card.h))
                r.scale = 2.77; uiImage = r.uiImage
            }
        } else {
            switch selectedCard {
            case 0:
                let r = ImageRenderer(content:
                    ShareCardToday(stats: stats, goal: goal, palette: palette, isDark: isDark, date: today)
                        .frame(width: card.w, height: card.h))
                r.scale = 2.77; uiImage = r.uiImage
            case 1:
                let r = ImageRenderer(content:
                    ShareCardWeekly(stats: stats, goal: goal, palette: palette, isDark: isDark, days: days)
                        .frame(width: card.w, height: card.h))
                r.scale = 2.77; uiImage = r.uiImage
            default:
                let r = ImageRenderer(content:
                    ShareCardYear(stats: stats, goal: goal, palette: palette, isDark: isDark, days: days)
                        .frame(width: card.w, height: card.h))
                r.scale = 2.77; uiImage = r.uiImage
            }
        }

        isSaving = false
        guard let image = uiImage else { return }

        let av = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        var topVC = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
        while let presented = topVC?.presentedViewController {
            topVC = presented
        }
        topVC?.present(av, animated: true)
    }
}

// MARK: - Previews

#Preview("Dark") {
    let m = StepsModel.build()
    return ShareProgressSheet(days: m.days, stats: m.stats, goal: m.goal, selectedDay: nil, palette: .dark, isDark: true)
        .preferredColorScheme(.dark)
}

#Preview("Dark with Day") {
    let m = StepsModel.build()
    let day = m.days.filter { $0.date < Calendar.current.startOfDay(for: Date()) }.last
    return ShareProgressSheet(days: m.days, stats: m.stats, goal: m.goal, selectedDay: day, palette: .dark, isDark: true)
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    let m = StepsModel.build()
    return ShareProgressSheet(days: m.days, stats: m.stats, goal: m.goal, selectedDay: nil, palette: .light, isDark: false)
        .preferredColorScheme(.light)
}

#Preview("Card Today") {
    ShareCardToday(stats: StepsModel.build().stats, goal: 10_000, palette: .dark, isDark: true, date: Date())
        .preferredColorScheme(.dark)
}

#Preview("Card Day") {
    let m = StepsModel.build()
    let day = m.days.filter { $0.date < Calendar.current.startOfDay(for: Date()) }.last!
    return ShareCardDay(day: day, stats: m.stats, goal: m.goal, palette: .dark, isDark: true)
        .preferredColorScheme(.dark)
}

#Preview("Card Weekly") {
    ShareCardWeekly(stats: StepsModel.build().stats, goal: 10_000, palette: .dark, isDark: true, days: StepsModel.build().days)
        .preferredColorScheme(.dark)
}

#Preview("Card Year") {
    ShareCardYear(stats: StepsModel.build().stats, goal: 10_000, palette: .dark, isDark: true, days: StepsModel.build().days)
        .preferredColorScheme(.dark)
}
