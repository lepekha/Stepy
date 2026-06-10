import SwiftUI

// MARK: - Solid Continuous Grid
// 20-column seamless year grid, chronological left→right then wrapping down.
// Matches the "Continuous" design variant from the prototype.

struct SolidGridView: View {
    let days: [StepDay]
    let goal: Int
    let palette: HeatPalette
    let today: Date
    let futureColor: Color
    @Binding var selectedDay: StepDay?
    let todayBorderColor: Color
    let selectedBorderColor: Color

    private let cols = 20
    private let gap: CGFloat = 2.4
    @State private var preDragSelected: StepDay? = nil
    @State private var gestureActive = false

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: gap), count: cols),
            spacing: gap
        ) {
            ForEach(days) { day in
                let isFuture = day.date > today
                let isToday = Calendar.current.isDate(day.date, inSameDayAs: today)
                let isSelected = selectedDay?.id == day.id
                let fillColor: Color = isFuture
                    ? futureColor
                    : palette.colors[StepsModel.level(day.steps, goal: goal)]
                let borderColor: Color? = isSelected ? selectedBorderColor : (isToday && selectedDay == nil ? todayBorderColor : nil)
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(fillColor)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        Group {
                            if let bc = borderColor {
                                RoundedRectangle(cornerRadius: 3.5)
                                    .stroke(bc, lineWidth: 1.5)
                                    .padding(-1)
                            }
                        }
                    )
                    .animation(.spring(response: 0.18, dampingFraction: 0.75), value: isSelected)
            }
        }
        .overlay(
            GeometryReader { geo in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !gestureActive {
                                    gestureActive = true
                                    preDragSelected = selectedDay
                                }
                                let cellW = (geo.size.width - gap * CGFloat(cols - 1)) / CGFloat(cols)
                                guard let day = day(at: value.location, cellWidth: cellW),
                                      day.date <= today else { return }
                                let isToday = Calendar.current.isDate(day.date, inSameDayAs: today)
                                let newSelection: StepDay? = isToday ? nil : day
                                if selectedDay?.id != newSelection?.id {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    selectedDay = newSelection
                                }
                            }
                            .onEnded { value in
                                gestureActive = false
                                let dist = hypot(value.translation.width, value.translation.height)
                                if dist < 8 {
                                    let cellW = (geo.size.width - gap * CGFloat(cols - 1)) / CGFloat(cols)
                                    let tapped = day(at: value.location, cellWidth: cellW)
                                    let tappedEmpty = tapped == nil || tapped!.date > today
                                    let tappedToday = tapped.map { Calendar.current.isDate($0.date, inSameDayAs: today) } ?? false
                                    if preDragSelected?.id == tapped?.id || tappedEmpty || tappedToday {
                                        selectedDay = nil
                                    }
                                }
                            }
                    )
            }
        )
    }

    private func day(at point: CGPoint, cellWidth: CGFloat) -> StepDay? {
        let stride = cellWidth + gap
        let col = Int(point.x / stride)
        let row = Int(point.y / stride)
        guard col >= 0, col < cols, row >= 0 else { return nil }
        let index = row * cols + col
        guard index < days.count else { return nil }
        return days[index]
    }
}

// MARK: - Legend ("0 ■■■■■ 10K")

struct LegendView: View {
    let palette: HeatPalette
    let subColor: Color
    let goal: Int

    var body: some View {
        HStack(spacing: 5) {
            Text("0")
                .font(.system(size: 10))
                .foregroundColor(subColor)
                .monospacedDigit()
            HStack(spacing: 2.5) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1.3)
                        .fill(palette.colors[i])
                        .frame(width: 9, height: 9)
                }
            }
            Text(fmtCompact(goal))
                .font(.system(size: 10))
                .foregroundColor(subColor)
                .monospacedDigit()
        }
    }
}
