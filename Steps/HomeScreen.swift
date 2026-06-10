import SwiftUI

struct HomeScreen: View {
    @ObservedObject var viewModel: HomeViewModel
    @State private var selectedDay: StepDay?
    @State private var showingGoalEditor = false
    @State private var showingShareSheet = false
    @State private var unitVisible = true
    @State private var unitShowTask: Task<Void, Never>?

    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }
    private var theme: GHTheme { isDark ? .dark : .light }
    private var palette: HeatPalette { isDark ? .dark : .light }
    private var accent: Color { palette.accent(dark: isDark) }
    private let goalColor = Color(hex: "#C8952A")
    private var displayProgress: Double {
        guard let day = selectedDay else { return viewModel.progress }
        return min(1.0, Double(day.steps) / Double(viewModel.goal))
    }
    private var displayGoalReached: Bool { displayProgress >= 1.0 }
    private var displayProgressPercent: Int { Int((displayProgress * 100).rounded()) }
    private var displayCurrentText: String {
        guard let day = selectedDay else { return viewModel.todayText }
        return fmt(day.steps)
    }


    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                headerBar
                    .padding(.horizontal, 16)

                heroSection
                    .padding(.horizontal, 18)

                heatmapSection
                    .padding(.horizontal, 16)
                    .padding(.top, 20)

                Spacer(minLength: 8)
                    .frame(maxHeight: .infinity)

                statsRow
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
            }
            .redacted(reason: viewModel.isLoading ? .placeholder : [])
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)
        ) { _ in
            showingShareSheet = true
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareProgressSheet(
                days: viewModel.days,
                stats: viewModel.stats,
                goal: viewModel.goal,
                selectedDay: selectedDay,
                palette: palette,
                isDark: isDark
            )
            .presentationDetents([.height(460)])
            .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(alignment: .bottom) {
            Text(Strings.app_name)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(theme.text)
                .kerning(0.3)

            Spacer()
        }
        .padding(.bottom, 14)
        .sheet(isPresented: $showingGoalEditor) {
            GoalEditorSheet(
                currentGoal: viewModel.goal,
                isDark: isDark,
                theme: theme,
                accent: accent
            ) { newGoal in
                viewModel.updateGoal(newGoal)
            }
            .presentationDetents([.height(410)])
            .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let day = selectedDay {
                    Button {
                        selectedDay = nil
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "calendar")
                                .font(.system(size: 11, weight: .semibold))
                            Text(fmtDayFull(day.date))
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(0.1)
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .semibold))
                                .opacity(0.7)
                        }
                        .foregroundColor(accent)
                        .padding(.leading, 7)
                        .padding(.trailing, 9)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(accent.opacity(0.12))
                                .overlay(Capsule().stroke(accent.opacity(0.24), lineWidth: 1))
                        )
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale(0.95, anchor: .leading)))
                } else {
                    Text(Strings.today_label)
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(theme.sub)
                        .transition(.opacity)
                }
            }
            .frame(height: 24, alignment: .leading)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: selectedDay?.id)
            .padding(.bottom, 4)

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(selectedDay != nil ? fmt(selectedDay!.steps) : viewModel.todayText)
                    .font(.system(size: 54, weight: .heavy))
                    .kerning(-1.5)
                    .monospacedDigit()
                    .foregroundColor(theme.text)
                    .opacity(selectedDay != nil ? 0.68 : 1)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.28, dampingFraction: 0.72), value: selectedDay?.id)
                Text(Strings.steps_unit)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.sub)
                    .opacity(unitVisible ? 1 : 0)
                    .animation(unitVisible ? .easeIn(duration: 0.2) : nil, value: unitVisible)
            }
            .padding(.bottom, 14)
            .onChange(of: selectedDay?.id) { _ in
                unitShowTask?.cancel()
                unitVisible = false
                unitShowTask = Task {
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    guard !Task.isCancelled else { return }
                    await MainActor.run { unitVisible = true }
                }
            }

            goalBar
        }
    }

    private var goalBar: some View {
        VStack(spacing: 7) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.track)
                    Capsule()
                        .fill(displayGoalReached ? goalColor : accent)
                        .frame(width: geo.size.width * displayProgress)
                        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: displayProgress)
                        .animation(.easeInOut(duration: 0.25), value: displayGoalReached)
                }
                .frame(height: 8)
            }
            .frame(height: 8)

            HStack {
                if displayGoalReached {
                    Text(Strings.goal_reached_with_amount(goal: fmtCompact(viewModel.goal)))
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundColor(goalColor)
                        .transition(.opacity.combined(with: .scale(0.95, anchor: .leading)))
                } else {
                    Text(Strings.steps_progress(current: displayCurrentText, goal: viewModel.goalText))
                        .font(.system(size: 12.5))
                        .foregroundColor(theme.sub)
                        .contentTransition(.opacity)
                        .transition(.opacity.combined(with: .scale(0.95, anchor: .leading)))
                }
                Spacer()
                HStack(spacing: 6) {
                    if !displayGoalReached {
                        Text(Strings.percent_of_goal(percent: displayProgressPercent))
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(accent)
                            .contentTransition(.numericText())
                            .transition(.opacity)
                    }
                    Button {
                        showingGoalEditor = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(showingGoalEditor
                                      ? accent
                                      : (isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.07)))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    showingGoalEditor
                                        ? Circle().stroke(accent.opacity(0.19), lineWidth: 4)
                                        : nil
                                )
                            Image("ic_edit")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(showingGoalEditor ? .white : theme.sub)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: selectedDay?.id)
        }
    }

    // MARK: - Heatmap Section

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Text(viewModel.totalText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.text)
                Text(Strings.steps_in_last_year)
                    .font(.system(size: 13))
                    .foregroundColor(theme.sub)
                Spacer()
                LegendView(palette: palette, subColor: theme.sub, goal: viewModel.goal)
            }
            .padding(.bottom, 14)

            SolidGridView(
                days: viewModel.days,
                goal: viewModel.goal,
                palette: palette,
                today: Calendar.current.startOfDay(for: Date()),
                futureColor: theme.border,
                selectedDay: $selectedDay,
                todayBorderColor: theme.text,
                selectedBorderColor: theme.text
            )

            Text(viewModel.dateRangeText)
                .font(.system(size: 11.5))
                .foregroundColor(theme.faint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 34)
                .padding(.top, 14)
        }
    }

    // MARK: - Stats Row (divided by vertical lines, no boxes)

    private var statsRow: some View {
        let items: [(label: String, value: String, unit: String)] = [
            (Strings.daily_avg, viewModel.averageText,  Strings.steps_unit),
            (Strings.total_label, viewModel.totalCompact, viewModel.dayCountText),
            (Strings.record_label, viewModel.recordText, viewModel.recordDateText),
        ]

        return HStack(alignment: .top, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                if i > 0 {
                    Spacer()
                    Rectangle()
                        .fill(theme.border)
                        .frame(width: 1)
                        .padding(.vertical, 16)
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(item.label)
                        .font(.system(size: 10.5, weight: .semibold))
                        .tracking(0.4)
                        .foregroundColor(theme.sub)

                    Text(item.value)
                        .font(.system(size: 21, weight: .bold))
                        .kerning(-0.3)
                        .monospacedDigit()
                        .foregroundColor(theme.text)
                        .padding(.top, 5)

                    Text(item.unit)
                        .font(.system(size: 11))
                        .foregroundColor(theme.faint)
                        .padding(.top, 1)
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Goal Editor Sheet

private struct GoalEditorSheet: View {
    let currentGoal: Int
    let isDark: Bool
    let theme: GHTheme
    let accent: Color
    let onSave: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var goalValue: Int

    private let presets = [5_000, 7_000, 8_000, 10_000, 12_000, 15_000, 20_000, 25_000, 30_000]
    private let step = 500
    private let minGoal = 1000
    private let maxGoal = 100_000

    init(currentGoal: Int, isDark: Bool, theme: GHTheme, accent: Color, onSave: @escaping (Int) -> Void) {
        self.currentGoal = currentGoal
        self.isDark = isDark
        self.theme = theme
        self.accent = accent
        self.onSave = onSave
        _goalValue = State(initialValue: currentGoal)
    }

    private var sheetBg: Color  { isDark ? Color(hex: "#1c1c1e") : Color(hex: "#ffffff") }
    private var pillBg: Color   { isDark ? Color.white.opacity(0.11) : Color.black.opacity(0.055) }
    private var textCol: Color  { isDark ? Color(hex: "#ffffff") : Color(hex: "#000000") }
    private var divider: Color  { isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.07) }
    private var chipText: Color { isDark ? Color.white.opacity(0.72) : Color.black.opacity(0.62) }

    var body: some View {
        VStack(spacing: 0) {
            // handle
            RoundedRectangle(cornerRadius: 2)
                .fill(isDark ? Color.white.opacity(0.20) : Color.black.opacity(0.13))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 20)

            // title row
            HStack {
                Text(Strings.daily_goal)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(textCol)
                Spacer()
                Button {
                    onSave(goalValue)
                    dismiss()
                } label: {
                    Text(Strings.done)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(accent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 10).fill(accent.opacity(0.10)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 16)

            Divider()
                .background(divider)
                .padding(.horizontal, 22)

            // big number
            VStack(spacing: 5) {
                Text(fmt(goalValue))
                    .font(.system(size: 60, weight: .heavy).monospacedDigit())
                    .foregroundColor(textCol)
                    .kerning(-2.5)
                Text(Strings.steps_per_day)
                    .font(.system(size: 13))
                    .foregroundColor(theme.sub)
            }
            .padding(.top, 22)
            .padding(.bottom, 18)

            // stepper
            HStack(spacing: 24) {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        goalValue = max(minGoal, goalValue - step)
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    ZStack {
                        Circle().fill(pillBg).frame(width: 48, height: 48)
                        Rectangle()
                            .fill(textCol)
                            .frame(width: 18, height: 3)
                            .cornerRadius(1.5)
                    }
                }
                .buttonStyle(.plain)

                Text(Strings.stepper_label)
                    .font(.system(size: 12))
                    .foregroundColor(theme.sub)
                    .frame(minWidth: 68)

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        goalValue = min(maxGoal, goalValue + step)
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    ZStack {
                        Circle().fill(pillBg).frame(width: 48, height: 48)
                        VStack(spacing: 0) {
                            Rectangle().fill(textCol).frame(width: 2, height: 18).cornerRadius(1)
                        }
                        HStack(spacing: 0) {
                            Rectangle().fill(textCol).frame(width: 18, height: 2).cornerRadius(1)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 22)

            // preset chips — two rows
            VStack(spacing: 8) {
                ForEach([Array(presets.prefix(5)), Array(presets.suffix(4))], id: \.first) { row in
                    HStack(spacing: 8) {
                        ForEach(row, id: \.self) { preset in
                            let isActive = goalValue == preset
                            Button {
                                withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) {
                                    goalValue = preset
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Text(fmtCompact(preset))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(isActive ? .white : chipText)
                                    .padding(.horizontal, 17)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(isActive ? accent : pillBg))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.vertical)
            .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity)
        .background(sheetBg.ignoresSafeArea())
    }
}

// MARK: - Preview

#Preview("Light") {
    HomeScreen(viewModel: HomeViewModel())
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    HomeScreen(viewModel: HomeViewModel())
        .preferredColorScheme(.dark)
}
