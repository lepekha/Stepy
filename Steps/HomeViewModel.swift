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

    private var cancellables = Set<AnyCancellable>()
    private static let goalKey = "daily_goal"

    init(goal: Int? = nil) {
        let saved = UserDefaults.standard.integer(forKey: HomeViewModel.goalKey)
        let resolved = goal ?? (saved > 0 ? saved : 10_000)
        let mock = StepsModel.build(goal: resolved)
        self.days = mock.days
        self.stats = mock.stats
        self.goal = resolved
        Task { await startLiveUpdates() }

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

    var dateRangeText: String {
        guard let first = days.first?.date, let last = days.last?.date else { return "" }
        return "\(fmtMonthYear(first)) – \(fmtMonthYear(last)) · \(Strings.tap_any_day)"
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
