//
//  LocalizedStrings.swift
//  Steps
//
//  Created by Ruslan Lepekha on 06.06.2026.
//

import Foundation

struct Strings {
    static var app_name: String { "app_name".localized() }

    // Home
    static var today_label: String { "today_label".localized() }
    static var steps_unit: String { "steps_unit".localized() }
    static var goal_reached: String { "goal_reached".localized() }
    static var goal_reached_multiline: String { "goal_reached_multiline".localized() }
    static func goal_reached_with_amount(goal: String) -> String { String(format: "goal_reached_with_amount_format".localized(), goal) }
    static func percent_of_goal(percent: Int) -> String { String(format: "percent_of_goal_format".localized(), percent) }
    static func steps_progress(current: String, goal: String) -> String { String(format: "steps_progress_format".localized(), current, goal) }
    static var steps_in_last_year: String { "steps_in_last_year".localized() }

    // Goal Editor
    static var daily_goal: String { "daily_goal".localized() }
    static var done: String { "done".localized() }
    static var steps_per_day: String { "steps_per_day".localized() }
    static var stepper_label: String { "stepper_label".localized() }

    // Stats Row
    static var daily_avg: String { "daily_avg".localized() }
    static var total_label: String { "total_label".localized() }
    static var record_label: String { "record_label".localized() }
    static func days_count(count: Int) -> String { String(format: "days_count_format".localized(), count) }
    static var tap_any_day: String { "tap_any_day".localized() }

    // Heatmap
    static func steps_day(day: String, year: Int) -> String { String(format: "steps_day_format".localized(), day, year) }
    static var legend_less: String { "legend_less".localized() }
    static var legend_more: String { "legend_more".localized() }

    // Widget
    static var month_label: String { "month_label".localized() }
    static func of_goal(goal: String) -> String { String(format: "of_goal_format".localized(), goal) }
    static var widget_medium_name: String { "widget_medium_name".localized() }
    static var widget_medium_description: String { "widget_medium_description".localized() }
    static var widget_small_name: String { "widget_small_name".localized() }
    static var widget_small_description: String { "widget_small_description".localized() }
    static var last_update_label: String { "last_update_label".localized() }
    static var updated_now: String { "updated_now".localized() }
    static func updated_min_ago(_ m: Int) -> String { String(format: "updated_min_ago_format".localized(), m) }
    static func updated_hours_ago(_ h: Int) -> String { String(format: "updated_hours_ago_format".localized(), h) }

    // Share Sheet
    static var share_your_progress: String { "share_your_progress".localized() }
    static var share_today: String { "share_today".localized() }
    static var share_weekly: String { "share_weekly".localized() }
    static var share_year: String { "share_year".localized() }
    static var share_day: String { "share_day".localized() }
    static var share_preparing: String { "share_preparing".localized() }
    static var share_button: String { "share_button".localized() }
    static var share_cancel: String { "share_cancel".localized() }
    static var share_steps_today: String { "share_steps_today".localized() }
    static var share_avg_per_day: String { "share_avg_per_day".localized() }
    static var share_total: String { "share_total".localized() }
    static var share_record: String { "share_record".localized() }
    static var share_goal_label: String { "share_goal_label".localized() }
    static var share_this_week: String { "share_this_week".localized() }
    static func share_days_goal_reached(_ goalDays: Int, _ total: Int) -> String {
        String(format: "share_days_goal_reached_format".localized(), goalDays, total)
    }
    static var share_best_day: String { "share_best_day".localized() }
    static var share_goal_days: String { "share_goal_days".localized() }
    static var share_total_steps: String { "share_total_steps".localized() }
    static var share_record_day: String { "share_record_day".localized() }
    static var share_days_at_goal: String { "share_days_at_goal".localized() }
    static var share_daily_avg: String { "share_daily_avg".localized() }
    static var share_success_rate: String { "share_success_rate".localized() }
    static var share_total_steps_year: String { "share_total_steps_year".localized() }
}

extension String {
    func localized() -> String {
        NSLocalizedString(self, comment: "")
    }
}
