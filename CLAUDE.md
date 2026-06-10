# Steps — iOS Pedometer App

## Build & Run
Open `Steps.xcodeproj` in Xcode. No CLI build. Target a real device — HealthKit requires hardware (simulator returns no data).

Scheme `Steps` builds the app. `StepsWidget` is the widget extension, built alongside automatically.

## Architecture

Two targets sharing one App Group:

```
Steps/           — main iOS app
  StepsApp.swift      — @main, requests HealthKit auth on launch
  ContentView.swift   — root view, owns HomeViewModel
  HomeScreen.swift    — full UI: header, hero (today count + goal bar), heatmap, stats row
  HomeViewModel.swift — @MainActor ObservableObject; drives UI from HealthKitService
  HealthKitService.swift — actor; HKStatisticsCollectionQuery live updates + background delivery
  HeatmapView.swift   — SolidGridView (20-col year grid), DayTooltipView, LegendView
  ShareSheet.swift    — ShareProgressSheet + ShareCardToday/Day/Weekly/Year; ImageRenderer PNG export
  LocalizedStrings.swift — typed Strings struct; all user-facing strings via NSLocalizedString
  StepsModel.swift    — pure structs (StepDay, StepStats, StepsModel), GHTheme, HeatPalette, fmt helpers
StepsWidget/     — WidgetKit extension (small + medium)
  StepsWidget.swift       — provider reads shared UserDefaults; falls back to mock data
  StepsWidgetBundle.swift — registers both widget configs
```

## Firebase
`GoogleService-Info.plist` required at `Steps/GoogleService-Info.plist` (gitignored — add manually after clone).
`AppDelegate` calls `FirebaseApp.configure()` on launch.

## Localization
22 locales. All strings go through `Strings` struct in `LocalizedStrings.swift` — add new key there plus matching entry in every `*.lproj/Localizable.strings`.

## Deployment
```bash
bundle exec fastlane release   # increments build number, archives, uploads to App Store
```
App ID: `app.stepy` · Apple ID: `ruslan.lepekha@gmail.com` · Team: `H2QH4W996F`

## Shared Data (App ↔ Widget)

App Group: `group.app.steps.Steps`  
`HealthKitService.saveToSharedStorage` writes `[yyyy-MM-dd: Int]` JSON to UserDefaults suite.  
Widget reads the same key. If missing, widget renders deterministic mock data.

## HealthKit Entitlements
Both `Steps.entitlements` and `StepsWidgetExtension.entitlements` must include HealthKit capability. Background delivery is registered in `StepsApp.init()` via `enableBackgroundDelivery()`.

## Design System
GitHub contribution graph aesthetic. Two themes: `GHTheme` (bg/text/border colors), `HeatPalette` (5-level green scale, indices 0–4 where 0 = empty). Heat level thresholds: 0%→L0, <45%→L1, <80%→L2, <100%→L3, ≥100%→L4.

## Mock Data
`StepsModel.build()` uses Mulberry32 RNG seeded by date — same algorithm as the JS prototype — so preview data is deterministic and matches across platforms. Widget uses the same RNG in `StepsProvider.mockSteps(for:)`.

## Goal Persistence
`UserDefaults.standard` key `daily_goal` (Int). Minimum 100, step 500. Updated via `HomeViewModel.updateGoal(_:)`.

## Key Gotchas
- `ImageRenderer` can't capture lazy views — share cards use eager `VStack`/`HStack`, never `LazyVGrid`. Share card sizes are fixed (390×390 or 390×693); don't use `GeometryReader` at root of share cards.
- HealthKit returns no data on Simulator — always test on device.
- `HKStatisticsCollectionQuery` fires both `initialResultsHandler` and `statisticsUpdateHandler`; both call the same closure.
- Widget timeline refreshes every 30 min; HealthKit observer also calls `WidgetCenter.shared.reloadAllTimelines()` on background delivery.
- `SolidGridView` uses 20 columns (not 52-week GitHub layout) — chronological left→right wrap, not week-aligned.
