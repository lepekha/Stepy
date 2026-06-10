import HealthKit
import WidgetKit

private let appGroupID = "group.app.stepy"
private let sharedStepsKey = "sharedStepsByDate"
private let sharedGoalKey = "sharedGoal"
private let sharedUpdatedKey = "sharedUpdatedAt"

actor HealthKitService {
    static let shared = HealthKitService()
    private let store = HKHealthStore()
    private var liveQuery: HKStatisticsCollectionQuery?
    private var observerQuery: HKObserverQuery?

    private init() {}

    func isAvailable() -> Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuth() async -> Bool {
        guard isAvailable() else { return false }
        let type = HKQuantityType(.stepCount)
        return (try? await store.requestAuthorization(toShare: [], read: [type])) != nil
    }

    func startLiveUpdates(goal: Int, onUpdate: @escaping @Sendable ((days: [StepDay], stats: StepStats)?) -> Void) {
        if let q = liveQuery { store.stop(q) }

        guard isAvailable() else { return }

        let type = HKQuantityType(.stepCount)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let year = cal.component(.year, from: today)
        guard let start = cal.date(from: DateComponents(year: year, month: 1, day: 1)),
              let yearEnd = cal.date(from: DateComponents(year: year, month: 12, day: 31))
        else { return }

        var comps = DateComponents()
        comps.day = 1
        let pred = HKQuery.predicateForSamples(withStart: start, end: .distantFuture)

        let query = HKStatisticsCollectionQuery(
            quantityType: type,
            quantitySamplePredicate: pred,
            options: .cumulativeSum,
            anchorDate: today,
            intervalComponents: comps
        )

        let handle: (HKStatisticsCollection?) -> Void = { collection in
            guard let collection else { onUpdate(nil); return }

            var days: [StepDay] = []
            collection.enumerateStatistics(from: start, to: yearEnd) { stat, _ in
                let steps = Int(stat.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                days.append(StepDay(id: days.count, date: stat.startDate, steps: steps))
            }
            guard !days.isEmpty else { onUpdate(nil); return }

            let pastDays = days.filter { $0.date <= today }
            let total = pastDays.reduce(0) { $0 + $1.steps }
            let recordDay = pastDays.max { $0.steps < $1.steps }
            let todaySteps = pastDays.last?.steps ?? 0

            var streak = 0
            for day in pastDays.dropLast().reversed() {
                if day.steps >= goal { streak += 1 } else { break }
            }

            let stats = StepStats(
                today: todaySteps,
                average: total / max(1, pastDays.count),
                total: total,
                record: recordDay?.steps ?? 0,
                recordDate: recordDay?.date,
                streak: streak,
                dayCount: pastDays.count
            )

            HealthKitService.saveToSharedStorage(days: days, goal: goal)
            onUpdate((days, stats))
        }

        query.initialResultsHandler = { _, collection, _ in handle(collection) }
        query.statisticsUpdateHandler = { _, _, collection, _ in handle(collection) }

        liveQuery = query
        store.execute(query)
    }

    func stopLiveUpdates() {
        if let q = liveQuery { store.stop(q); liveQuery = nil }
    }

    func enableBackgroundDelivery() {
        guard isAvailable() else { return }
        let stepType = HKQuantityType(.stepCount)

        store.enableBackgroundDelivery(for: stepType, frequency: .immediate) { _, _ in }

        if let q = observerQuery { store.stop(q) }
        let q = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completion, error in
            guard error == nil, let self else { completion(); return }
            Task {
                let goal = await self.savedGoal()
                await self.fetchSnapshot(goal: goal)
                WidgetCenter.shared.reloadAllTimelines()
                completion()
            }
        }
        observerQuery = q
        store.execute(q)
    }

    private func savedGoal() -> Int {
        let fromGroup = UserDefaults(suiteName: appGroupID)?.integer(forKey: sharedGoalKey) ?? 0
        if fromGroup > 0 { return fromGroup }
        let fromStandard = UserDefaults.standard.integer(forKey: "daily_goal")
        return fromStandard > 0 ? fromStandard : 10_000
    }

    private func fetchSnapshot(goal: Int) async {
        guard isAvailable() else { return }
        let type = HKQuantityType(.stepCount)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let year = cal.component(.year, from: today)
        guard let start = cal.date(from: DateComponents(year: year, month: 1, day: 1)),
              let yearEnd = cal.date(from: DateComponents(year: year, month: 12, day: 31))
        else { return }

        var comps = DateComponents(); comps.day = 1
        let pred = HKQuery.predicateForSamples(withStart: start, end: .distantFuture)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let q = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: pred,
                options: .cumulativeSum,
                anchorDate: today,
                intervalComponents: comps
            )
            q.initialResultsHandler = { _, collection, _ in
                guard let collection else { continuation.resume(); return }
                var days: [StepDay] = []
                collection.enumerateStatistics(from: start, to: yearEnd) { stat, _ in
                    let steps = Int(stat.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                    days.append(StepDay(id: days.count, date: stat.startDate, steps: steps))
                }
                if !days.isEmpty {
                    HealthKitService.saveToSharedStorage(days: days, goal: goal)
                }
                continuation.resume()
            }
            store.execute(q)
        }
    }

    private static func saveToSharedStorage(days: [StepDay], goal: Int) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        var dict: [String: Int] = [:]
        for day in days {
            dict[fmt.string(from: day.date)] = day.steps
        }
        if let data = try? JSONEncoder().encode(dict) {
            defaults.set(data, forKey: sharedStepsKey)
            defaults.set(goal, forKey: sharedGoalKey)
            defaults.set(Date().timeIntervalSince1970, forKey: sharedUpdatedKey)
        }
    }
}
