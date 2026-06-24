import SwiftUI
import Combine
import UIKit
import WidgetKit

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var days: [StepDay]
    @Published private(set) var stats: StepStats
    @Published private(set) var goal: Int
    @Published private(set) var isLoading = true

    /// Year shown in the heatmap. Hero + stats always reflect the live current year.
    @Published private(set) var selectedYear: Int
    @Published private(set) var availableYears: [Int]
    @Published private(set) var heatmapDays: [StepDay]

    let currentYear = Calendar.current.component(.year, from: Date())

    private var cancellables = Set<AnyCancellable>()
    private static let goalKey = "daily_goal"

    init(goal: Int? = nil) {
        let saved = UserDefaults.standard.integer(forKey: HomeViewModel.goalKey)
        let resolved = goal ?? (saved > 0 ? saved : 10_000)
        let mock = StepsModel.build(goal: resolved, todaySteps: 0)
        self.days = mock.days
        self.stats = mock.stats
        self.goal = resolved
        let year = Calendar.current.component(.year, from: Date())
        self.selectedYear = year
        self.availableYears = [year]
        self.heatmapDays = mock.days
        Task { await startLiveUpdates() }
        Task { await loadAvailableYears() }

        NotificationCenter.default
            .publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.startLiveUpdates()
                }
            }
            .store(in: &cancellables)
    }

    private func startLiveUpdates() async {
        let svc = HealthKitService.shared
        _ = await svc.requestAuth()
        let goal = self.goal
        await svc.startLiveUpdates(goal: goal) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.days = result.days
                    self.stats = result.stats
                    if self.selectedYear == self.currentYear {
                        self.heatmapDays = result.days
                    }
                    WidgetCenter.shared.reloadAllTimelines()
                }
                self.isLoading = false
            }
        }
    }

    // MARK: - Formatted outputs

    var todayText: String      { fmt(stats.today) }
    var goalText: String       { fmt(goal) }
    var totalText: String      { fmt(stats.total) }
    var totalCompact: String   { fmtCompact(stats.total) }
    var averageText: String    { fmt(stats.average) }
    var recordText: String     { fmt(stats.record) }
    var recordDateText: String { fmtDay(stats.recordDate) }
    var dayCountText: String   { Strings.days_count(count: stats.dayCount) }
    var progress: Double       { min(1.0, Double(stats.today) / Double(goal)) }
    var progressPercent: Int   { Int((progress * 100).rounded()) }

    /// Stats derived from the year currently shown in the heatmap.
    var heatmapStats: StepStats {
        let today = Calendar.current.startOfDay(for: Date())
        let pastDays = heatmapDays.filter { $0.date <= today }
        let total = pastDays.reduce(0) { $0 + $1.steps }
        let recordDay = pastDays.max { $0.steps < $1.steps }
        return StepStats(
            today: pastDays.last?.steps ?? 0,
            average: total / max(1, pastDays.count),
            total: total,
            record: recordDay?.steps ?? 0,
            recordDate: recordDay?.date,
            streak: 0,
            dayCount: pastDays.count
        )
    }

    var heatmapTotalText: String   { fmt(heatmapStats.total) }
    var heatmapAverageText: String { fmt(heatmapStats.average) }
    var heatmapTotalCompact: String { fmtCompact(heatmapStats.total) }
    var heatmapRecordText: String  { fmt(heatmapStats.record) }
    var heatmapRecordDateText: String { fmtDay(heatmapStats.recordDate) }
    var heatmapDayCountText: String { Strings.days_count(count: heatmapStats.dayCount) }

    var dateRangeText: String {
        guard let first = heatmapDays.first?.date, let last = heatmapDays.last?.date else { return "" }
        return "\(fmtMonthYear(first)) – \(fmtMonthYear(last)) · \(Strings.tap_any_day)"
    }

    // MARK: - Year selection

    func selectYear(_ year: Int) {
        guard year != selectedYear else { return }
        selectedYear = year
        if year == currentYear {
            heatmapDays = days
            return
        }
        Task {
            let fetched = await HealthKitService.shared.fetchYear(year)
            guard self.selectedYear == year else { return }
            self.heatmapDays = fetched.isEmpty ? Self.zeroDays(for: year) : fetched
        }
    }

    private func loadAvailableYears() async {
        let years = await HealthKitService.shared.availableYears()
        guard !years.isEmpty else { return }
        self.availableYears = years
    }

    private static func zeroDays(for year: Int) -> [StepDay] {
        let cal = Calendar.current
        guard let start = cal.date(from: DateComponents(year: year, month: 1, day: 1)) else { return [] }
        var days: [StepDay] = []
        var date = start
        var i = 0
        while cal.component(.year, from: date) == year {
            days.append(StepDay(id: i, date: date, steps: 0))
            i += 1
            guard let next = cal.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return days
    }

    func updateGoal(_ newGoal: Int) {
        guard newGoal >= 100 else { return }
        goal = newGoal
        UserDefaults.standard.set(newGoal, forKey: HomeViewModel.goalKey)
        Task { await startLiveUpdates() }
    }

    func level(for day: StepDay) -> Int {
        StepsModel.level(day.steps, goal: goal)
    }
}
